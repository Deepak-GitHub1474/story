"""One call, two histories, because two people own their own record of it."""

from datetime import timedelta

import pytest
import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.api.endpoints.calls.controllers import record_call
from app.core.time import utc_now


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def a_call(mongo, *, outcome=c.ANSWERED, seconds=120, relayed=False):
    started = utc_now()
    connected = started + timedelta(seconds=5) if outcome == c.ANSWERED else None
    await record_call(
        call_id="cal_x",
        caller_id="usr_caller",
        callee_id="usr_callee",
        conversation_id="cnv_1",
        outcome=outcome,
        started_at=started,
        connected_at=connected,
        ended_at=started + timedelta(seconds=seconds),
        relayed=relayed,
        mongo=mongo,
    )
    return started


async def test_one_call_writes_a_row_for_each_person(mongo):
    await a_call(mongo)

    assert await mongo[c.CALLS].count_documents({"call_id": "cal_x"}) == 2
    owners = {row["owner_id"] async for row in mongo[c.CALLS].find({}, {"owner_id": 1})}
    assert owners == {"usr_caller", "usr_callee"}


async def test_each_row_knows_which_way_the_call_went(mongo):
    await a_call(mongo)

    caller = await mongo[c.CALLS].find_one({"owner_id": "usr_caller"})
    callee = await mongo[c.CALLS].find_one({"owner_id": "usr_callee"})
    assert caller["direction"] == c.OUTBOUND
    assert caller["peer_id"] == "usr_callee"
    assert callee["direction"] == c.INBOUND
    assert callee["peer_id"] == "usr_caller"


async def test_duration_counts_from_the_moment_it_connected(mongo):
    await a_call(mongo, seconds=125)

    row = await mongo[c.CALLS].find_one({"owner_id": "usr_caller"})
    assert row["duration_seconds"] == 120


async def test_a_call_nobody_answered_has_no_duration(mongo):
    await a_call(mongo, outcome=c.MISSED, seconds=45)

    row = await mongo[c.CALLS].find_one({"owner_id": "usr_callee"})
    assert row["outcome"] == c.MISSED
    assert row["duration_seconds"] == 0
    assert row["connected_at"] is None


async def test_media_is_a_list_so_video_needs_no_migration(mongo):
    await a_call(mongo)

    row = await mongo[c.CALLS].find_one({"owner_id": "usr_caller"})
    assert row["media"] == [c.AUDIO]


async def test_whether_it_relayed_is_recorded_so_the_question_can_be_answered(mongo):
    """Buying a relay closer to users is a decision that needs a number."""
    await a_call(mongo, relayed=True)

    row = await mongo[c.CALLS].find_one({"owner_id": "usr_caller"})
    assert row["relayed"] is True


async def test_the_default_retention_is_stamped_on_each_row(mongo):
    started = await a_call(mongo)

    row = await mongo[c.CALLS].find_one({"owner_id": "usr_caller"})
    assert row["expires_at"] == started + timedelta(days=30)


async def test_a_person_who_chose_forever_gets_no_expiry(mongo):
    await mongo["users"].insert_one(
        {"_id": "usr_caller", "prefs": {"call_history_days": 0}}
    )

    await a_call(mongo)

    caller = await mongo[c.CALLS].find_one({"owner_id": "usr_caller"})
    callee = await mongo[c.CALLS].find_one({"owner_id": "usr_callee"})
    assert caller["expires_at"] is None
    assert callee["expires_at"] is not None


@pytest.mark.parametrize("outcome", [c.MISSED, c.DECLINED, c.BUSY, c.FAILED])
async def test_every_ending_is_recorded_not_only_the_happy_one(mongo, outcome):
    await a_call(mongo, outcome=outcome)

    assert await mongo[c.CALLS].count_documents({"outcome": outcome}) == 2
