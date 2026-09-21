"""Deleting means the row is gone, and only ever your own."""

import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.core.time import utc_now


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def auth(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def me(client, mongo, payload):
    headers = await auth(client, payload)
    person = await mongo["users"].find_one(
        {"username_lower": payload["username"].lower()}, {"_id": 1}
    )
    return headers, person["_id"]


async def seed(mongo, owner_id, call_ids):
    now = utc_now()
    await mongo[c.CALLS].insert_many(
        [
            {
                "_id": f"chi_{owner_id}_{call_id}",
                "call_id": call_id,
                "owner_id": owner_id,
                "peer_id": "usr_peer",
                "conversation_id": "cnv_1",
                "direction": c.OUTBOUND,
                "outcome": c.ANSWERED,
                "media": [c.AUDIO],
                "relayed": False,
                "started_at": now,
                "connected_at": now,
                "ended_at": now,
                "duration_seconds": 30,
                "expires_at": None,
            }
            for call_id in call_ids
        ]
    )


async def test_deleting_one_call_removes_the_row_entirely(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, ["cal_a", "cal_b"])

    response = await client.delete("/v1/calls/cal_a", headers=headers)

    assert response.status_code == 200
    assert await mongo[c.CALLS].count_documents({"call_id": "cal_a"}) == 0
    assert await mongo[c.CALLS].count_documents({"call_id": "cal_b"}) == 1


async def test_deleting_your_copy_leaves_theirs_alone(client, signup_payload, mongo):
    """Two rows per call exist exactly so this is true."""
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, ["cal_a"])
    await seed(mongo, "usr_peer", ["cal_a"])

    await client.delete("/v1/calls/cal_a", headers=headers)

    assert await mongo[c.CALLS].count_documents({"owner_id": "usr_peer"}) == 1


async def test_selected_calls_go_in_one_request(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, ["cal_a", "cal_b", "cal_c"])

    response = await client.post(
        "/v1/calls/delete", json={"call_ids": ["cal_a", "cal_c"]}, headers=headers
    )

    assert response.json()["data"]["deleted"] == 2
    remaining = [row["call_id"] async for row in mongo[c.CALLS].find({}, {"call_id": 1})]
    assert remaining == ["cal_b"]


async def test_clearing_everything_leaves_nothing(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, ["cal_a", "cal_b", "cal_c"])

    response = await client.post("/v1/calls/delete", json={"all": True}, headers=headers)

    assert response.json()["data"]["deleted"] == 3
    assert await mongo[c.CALLS].count_documents({"owner_id": user_id}) == 0


async def test_you_cannot_clear_a_stranger_out_of_their_own_history(
    client, signup_payload, mongo
):
    headers, _ = await me(client, mongo, signup_payload)
    await seed(mongo, "usr_stranger", ["cal_a"])

    await client.post("/v1/calls/delete", json={"all": True}, headers=headers)

    assert await mongo[c.CALLS].count_documents({"owner_id": "usr_stranger"}) == 1


async def test_deleting_a_call_you_do_not_have_is_not_an_error(client, signup_payload):
    headers = await auth(client, signup_payload)

    response = await client.delete("/v1/calls/cal_missing", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["deleted"] == 0


async def test_an_empty_selection_deletes_nothing(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, ["cal_a"])

    response = await client.post("/v1/calls/delete", json={"call_ids": []}, headers=headers)

    assert response.json()["data"]["deleted"] == 0
    assert await mongo[c.CALLS].count_documents({}) == 1
