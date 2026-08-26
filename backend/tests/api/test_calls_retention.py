"""How long a call is remembered, and what happens when a person changes their mind."""

from datetime import timedelta

import pytest
import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.config import Settings
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


async def seed(mongo, owner_id, started_at, row_id="chi_one"):
    await mongo[c.CALLS].insert_one(
        {
            "_id": row_id,
            "call_id": "cal_a",
            "owner_id": owner_id,
            "peer_id": "usr_peer",
            "conversation_id": "cnv_1",
            "direction": c.OUTBOUND,
            "outcome": c.ANSWERED,
            "media": [c.AUDIO],
            "relayed": False,
            "started_at": started_at,
            "connected_at": started_at,
            "ended_at": started_at,
            "duration_seconds": 30,
            "expires_at": started_at + timedelta(days=30),
        }
    )


def test_thirty_days_is_the_default():
    assert Settings().CALL_HISTORY_RETENTION_DAYS == 30


async def test_shortening_retention_reaches_calls_already_recorded(
    client, signup_payload, mongo
):
    """A privacy control that only applies to the future is not one."""
    headers, user_id = await me(client, mongo, signup_payload)
    started = utc_now()
    await seed(mongo, user_id, started)

    await client.put("/v1/calls/retention", json={"days": 1}, headers=headers)

    row = await mongo[c.CALLS].find_one({"_id": "chi_one"})
    assert row["expires_at"] == started + timedelta(days=1)


async def test_choosing_forever_clears_every_expiry(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, utc_now())

    await client.put("/v1/calls/retention", json={"days": 0}, headers=headers)

    row = await mongo[c.CALLS].find_one({"_id": "chi_one"})
    assert row["expires_at"] is None


async def test_the_setting_is_remembered_for_the_next_call(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)

    response = await client.put("/v1/calls/retention", json={"days": 7}, headers=headers)

    assert response.status_code == 200
    person = await mongo["users"].find_one({"_id": user_id}, {"prefs": 1})
    assert person["prefs"]["call_history_days"] == 7


async def test_changing_your_setting_never_touches_another_persons_rows(
    client, signup_payload, mongo
):
    headers, _ = await me(client, mongo, signup_payload)
    started = utc_now()
    await seed(mongo, "usr_peer", started, row_id="chi_theirs")

    await client.put("/v1/calls/retention", json={"days": 1}, headers=headers)

    row = await mongo[c.CALLS].find_one({"_id": "chi_theirs"})
    assert row["expires_at"] == started + timedelta(days=30)


async def test_the_number_of_restamped_rows_is_reported(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    now = utc_now()
    await seed(mongo, user_id, now, row_id="chi_a")
    await seed(mongo, user_id, now, row_id="chi_b")

    data = (
        await client.put("/v1/calls/retention", json={"days": 7}, headers=headers)
    ).json()["data"]

    assert data["restamped"] == 2
    assert data["call_history_days"] == 7


@pytest.mark.parametrize("days", [-1, 400])
async def test_a_nonsense_retention_is_refused(client, signup_payload, days):
    headers = await auth(client, signup_payload)

    response = await client.put("/v1/calls/retention", json={"days": days}, headers=headers)

    assert response.status_code == 422


async def test_retention_is_not_mistaken_for_a_call_id(client, signup_payload):
    """The route order matters: DELETE /calls/{id} must not swallow it."""
    headers = await auth(client, signup_payload)

    response = await client.put("/v1/calls/retention", json={"days": 7}, headers=headers)

    assert response.status_code == 200
