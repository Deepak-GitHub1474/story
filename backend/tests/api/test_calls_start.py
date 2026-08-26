"""Who may ring whom, and what the caller gets back."""

import pytest
import pytest_asyncio

from app.api.endpoints.chat import constants as chat_c

PASSWORD = "a-long-enough-password"


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def auth(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def a_payload(username):
    return {"username": username, "password": PASSWORD, "tnc_accepted": True}


@pytest.fixture
def other_payload(unique_username):
    return a_payload(f"{unique_username}b")


async def a_pair(client, mongo, first, second, *, state=chat_c.ACCEPTED):
    headers_a = await auth(client, first)
    await auth(client, second)
    users = mongo["users"]
    a = await users.find_one({"username_lower": first["username"].lower()}, {"_id": 1})
    b = await users.find_one({"username_lower": second["username"].lower()}, {"_id": 1})
    await mongo[chat_c.CONVERSATIONS].insert_one(
        {
            "_id": "cnv_pair",
            "pair_key": f"{a['_id']}:{b['_id']}",
            "participant_ids": sorted((a["_id"], b["_id"])),
            "state": state,
            "requested_by": None,
        }
    )
    return headers_a, a["_id"], b["_id"]


async def test_a_call_into_an_accepted_conversation_is_allowed(
    client, signup_payload, other_payload, mongo
):
    headers, _, _ = await a_pair(client, mongo, signup_payload, other_payload)

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers
    )

    assert response.status_code == 201
    data = response.json()["data"]
    assert data["call_id"].startswith("cal_")
    assert data["ice_servers"]
    assert data["ring_timeout_seconds"] == 45
    assert data["media"] == ["audio"]


async def test_a_call_into_a_pending_conversation_is_refused(
    client, signup_payload, other_payload, mongo
):
    """A request to talk is not consent to be rung."""
    headers, _, _ = await a_pair(
        client, mongo, signup_payload, other_payload, state=chat_c.PENDING
    )

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "CALL_NOT_ALLOWED"


async def test_a_call_into_someone_elses_conversation_is_refused(
    client, signup_payload, other_payload, unique_username, mongo
):
    await a_pair(client, mongo, signup_payload, other_payload)
    outsider = await auth(client, a_payload(f"{unique_username}c"))

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=outsider
    )

    assert response.status_code == 404
    assert response.json()["data"]["code"] == "CONVERSATION_NOT_FOUND"


async def test_a_blocked_person_cannot_be_rung(
    client, signup_payload, other_payload, mongo
):
    headers, caller, callee = await a_pair(client, mongo, signup_payload, other_payload)
    await mongo["connections"].insert_one(
        {
            "_id": "con_block",
            "follower_id": callee,
            "followee_id": caller,
            "status": "blocked",
        }
    )

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "CALL_NOT_ALLOWED"


async def test_the_ring_is_held_in_redis_and_not_in_mongo(
    client, signup_payload, other_payload, mongo, app_instance
):
    """A call that never connects must not outlive a restart."""
    headers, _, _ = await a_pair(client, mongo, signup_payload, other_payload)

    data = (
        await client.post("/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers)
    ).json()["data"]

    assert await mongo["calls"].count_documents({}) == 0
    assert await app_instance.state.redis.get(f"ST:CALL:{data['call_id']}") is not None


async def test_the_caller_learns_who_they_are_ringing(
    client, signup_payload, other_payload, mongo
):
    headers, _, _ = await a_pair(client, mongo, signup_payload, other_payload)

    data = (
        await client.post("/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers)
    ).json()["data"]

    assert data["peer"]["username"] == other_payload["username"]
