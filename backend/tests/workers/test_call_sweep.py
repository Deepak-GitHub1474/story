"""Rows past their expiry, and the rows that must survive."""

from datetime import timedelta

import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.core.time import utc_now
from app.workers.call_sweep import sweep_expired_calls


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def a_row(mongo, row_id, expires_at):
    now = utc_now()
    await mongo[c.CALLS].insert_one(
        {
            "_id": row_id,
            "call_id": row_id,
            "owner_id": "usr_owner",
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
            "expires_at": expires_at,
        }
    )


async def test_an_expired_call_is_erased(mongo):
    await a_row(mongo, "chi_old", utc_now() - timedelta(minutes=1))

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 1
    assert await mongo[c.CALLS].count_documents({}) == 0


async def test_a_call_still_inside_its_window_is_left_alone(mongo):
    await a_row(mongo, "chi_fresh", utc_now() + timedelta(days=5))

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 0
    assert await mongo[c.CALLS].count_documents({}) == 1


async def test_keep_forever_is_never_swept(mongo):
    await a_row(mongo, "chi_forever", None)

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 0
    assert await mongo[c.CALLS].count_documents({}) == 1


async def test_the_sweep_costs_nothing_when_there_is_nothing_to_do(mongo):
    assert await sweep_expired_calls(mongo=mongo) == 0


async def test_only_the_expired_go_when_the_two_are_mixed(mongo):
    await a_row(mongo, "chi_old", utc_now() - timedelta(minutes=1))
    await a_row(mongo, "chi_fresh", utc_now() + timedelta(days=5))
    await a_row(mongo, "chi_forever", None)

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 1
    survivors = {row["_id"] async for row in mongo[c.CALLS].find({}, {"_id": 1})}
    assert survivors == {"chi_fresh", "chi_forever"}


async def test_the_scheduler_actually_runs_the_sweep(mongo, app_instance):
    """A sweeper nothing calls is a sweeper that does not exist."""
    from app.workers import scheduler

    await a_row(mongo, "chi_old", utc_now() - timedelta(minutes=1))

    assert "call_sweep" in [name for _, _, name in scheduler.jobs(app_instance)]
    assert await scheduler._sweep_calls(mongo) == 1
