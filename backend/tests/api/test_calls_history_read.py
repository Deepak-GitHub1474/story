"""Your history is yours: what you see, and what you must never see."""

from datetime import timedelta

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


async def seed(mongo, owner_id, count):
    now = utc_now()
    await mongo[c.CALLS].insert_many(
        [
            {
                "_id": f"chi_{owner_id}_{index:03d}",
                "call_id": f"cal_{index:03d}",
                "owner_id": owner_id,
                "peer_id": "usr_peer",
                "conversation_id": "cnv_1",
                "direction": c.OUTBOUND,
                "outcome": c.ANSWERED,
                "media": [c.AUDIO],
                "relayed": False,
                "started_at": now - timedelta(minutes=index),
                "connected_at": now - timedelta(minutes=index),
                "ended_at": now,
                "duration_seconds": 60,
                "expires_at": None,
            }
            for index in range(count)
        ]
    )


async def test_the_newest_call_is_first(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 3)

    items = (await client.get("/v1/calls", headers=headers)).json()["data"]["items"]

    assert [item["call_id"] for item in items] == ["cal_000", "cal_001", "cal_002"]


async def test_you_never_see_somebody_elses_history(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 1)
    await seed(mongo, "usr_stranger", 5)

    items = (await client.get("/v1/calls", headers=headers)).json()["data"]["items"]

    assert len(items) == 1


async def test_a_page_is_capped_and_says_there_is_more(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 40)

    data = (await client.get("/v1/calls?limit=10", headers=headers)).json()["data"]

    assert len(data["items"]) == 10
    assert data["has_more"] is True
    assert data["next_cursor"] is not None


async def test_the_cursor_walks_forward_without_repeating(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 12)

    first = (await client.get("/v1/calls?limit=5", headers=headers)).json()["data"]
    second = (
        await client.get(
            f"/v1/calls?limit=5&cursor={first['next_cursor']}", headers=headers
        )
    ).json()["data"]

    seen = [item["call_id"] for item in first["items"]] + [
        item["call_id"] for item in second["items"]
    ]
    assert len(seen) == len(set(seen))
    assert len(seen) == 10


async def test_the_last_page_says_there_is_no_more(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 3)

    data = (await client.get("/v1/calls?limit=10", headers=headers)).json()["data"]

    assert data["has_more"] is False
    assert data["next_cursor"] is None


async def test_an_empty_history_is_not_an_error(client, signup_payload):
    headers = await auth(client, signup_payload)

    response = await client.get("/v1/calls", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["items"] == []


async def test_history_can_be_scoped_to_one_conversation(client, signup_payload, mongo):
    """The chat thread shows only the calls that belong to it."""
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 2)
    await mongo[c.CALLS].update_one(
        {"call_id": "cal_000"}, {"$set": {"conversation_id": "cnv_other"}}
    )

    data = (
        await client.get("/v1/calls?conversation_id=cnv_1", headers=headers)
    ).json()["data"]

    assert [item["call_id"] for item in data["items"]] == ["cal_001"]


async def test_no_filter_still_returns_everything(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 3)

    data = (await client.get("/v1/calls", headers=headers)).json()["data"]

    assert len(data["items"]) == 3
