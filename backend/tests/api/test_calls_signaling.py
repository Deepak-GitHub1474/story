"""Relaying an offer, giving the callee what it needs, and recording the ending."""

import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.api.endpoints.calls.signaling import SIGNAL_TYPES, handle, save
from app.core.time import to_wire, utc_now


class FakeBus:
    def __init__(self):
        self.sent: list[tuple[list[str], dict]] = []

    async def publish(self, redis, user_ids, payload):
        self.sent.append((user_ids, payload))


@pytest_asyncio.fixture
async def redis(app_instance):
    return app_instance.state.redis


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


@pytest_asyncio.fixture
async def bus(monkeypatch):
    fake = FakeBus()
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", fake)
    return fake


@pytest_asyncio.fixture
async def ringing(redis):
    await save(
        "cal_x",
        {
            "call_id": "cal_x",
            "caller": "usr_caller",
            "callee": "usr_callee",
            "conversation_id": "cnv_1",
            "started_at": to_wire(utc_now()),
            "connected_at": None,
            "caller_profile": {"user_id": "usr_caller", "username": "ann"},
        },
        redis,
        45,
    )
    return "cal_x"


async def test_every_message_type_is_registered():
    assert frozenset(
        {"call.offer", "call.answer", "call.ice", "call.update", "call.end"}
    ) == SIGNAL_TYPES


async def test_an_offer_reaches_the_other_person(ringing, redis, bus):
    await handle(
        {"type": "call.offer", "call_id": "cal_x", "sdp": "v=0...", "media": ["audio"]},
        user_id="usr_caller",
        redis=redis,
    )

    targets, payload = bus.sent[0]
    assert targets == ["usr_callee"]
    assert payload["sdp"] == "v=0..."


async def test_the_offer_carries_ice_servers_the_callee_can_answer_with(
    ringing, redis, bus
):
    """Without these the callee has nothing to build a peer connection from."""
    await handle(
        {"type": "call.offer", "call_id": "cal_x", "sdp": "v=0...", "media": ["audio"]},
        user_id="usr_caller",
        redis=redis,
    )

    _, payload = bus.sent[0]
    assert payload["ice_servers"]
    assert payload["ice_servers"][0]["urls"][0].startswith("stun:")


async def test_the_offer_says_who_is_calling(ringing, redis, bus):
    await handle(
        {"type": "call.offer", "call_id": "cal_x", "sdp": "v=0..."},
        user_id="usr_caller",
        redis=redis,
    )

    _, payload = bus.sent[0]
    assert payload["caller"]["username"] == "ann"
    assert payload["conversation_id"] == "cnv_1"
    assert payload["ring_timeout_seconds"] == 45


async def test_answering_marks_the_call_connected(ringing, redis, bus):
    await handle(
        {"type": "call.answer", "call_id": "cal_x", "sdp": "v=0..."},
        user_id="usr_callee",
        redis=redis,
    )

    from app.api.endpoints.calls.signaling import load

    assert (await load("cal_x", redis))["connected_at"] is not None


async def test_a_stranger_cannot_inject_into_a_call(ringing, redis, bus):
    await handle(
        {"type": "call.ice", "call_id": "cal_x", "candidate": {"candidate": "a"}},
        user_id="usr_eavesdropper",
        redis=redis,
    )

    assert bus.sent == []


async def test_signaling_for_an_expired_call_goes_nowhere(redis, bus):
    await handle(
        {"type": "call.ice", "call_id": "cal_gone", "candidate": {"candidate": "a"}},
        user_id="usr_caller",
        redis=redis,
    )

    assert bus.sent == []


async def test_ending_a_call_clears_the_ring(ringing, redis, bus, mongo):
    await handle(
        {"type": "call.end", "call_id": "cal_x", "reason": "hangup"},
        user_id="usr_caller",
        redis=redis,
        mongo=mongo,
    )

    from app.api.endpoints.calls.signaling import load

    assert await load("cal_x", redis) is None


async def test_a_call_nobody_answered_is_recorded_as_missed(ringing, redis, bus, mongo):
    """The whole point of history: the call that did not happen still happened."""
    await handle(
        {"type": "call.end", "call_id": "cal_x", "reason": "timeout"},
        user_id="usr_caller",
        redis=redis,
        mongo=mongo,
    )

    rows = await mongo[c.CALLS].find({"call_id": "cal_x"}).to_list(length=10)
    assert len(rows) == 2
    assert {row["outcome"] for row in rows} == {c.MISSED}


async def test_a_declined_call_is_recorded_as_declined(ringing, redis, bus, mongo):
    await handle(
        {"type": "call.end", "call_id": "cal_x", "reason": "declined"},
        user_id="usr_callee",
        redis=redis,
        mongo=mongo,
    )

    rows = await mongo[c.CALLS].find({"call_id": "cal_x"}).to_list(length=10)
    assert {row["outcome"] for row in rows} == {c.DECLINED}


async def test_a_call_that_connected_is_recorded_as_answered(ringing, redis, bus, mongo):
    await handle(
        {"type": "call.answer", "call_id": "cal_x", "sdp": "v=0..."},
        user_id="usr_callee",
        redis=redis,
    )
    await handle(
        {"type": "call.end", "call_id": "cal_x", "reason": "hangup"},
        user_id="usr_caller",
        redis=redis,
        mongo=mongo,
    )

    rows = await mongo[c.CALLS].find({"call_id": "cal_x"}).to_list(length=10)
    assert {row["outcome"] for row in rows} == {c.ANSWERED}
    assert all(row["connected_at"] is not None for row in rows)


async def test_candidates_are_forwarded_both_ways(ringing, redis, bus):
    await handle(
        {"type": "call.ice", "call_id": "cal_x", "candidate": {"candidate": "a"}},
        user_id="usr_caller",
        redis=redis,
    )

    targets, payload = bus.sent[0]
    assert targets == ["usr_callee"]
    assert payload["candidate"] == {"candidate": "a"}


async def test_mute_reaches_the_other_side(ringing, redis, bus):
    await handle(
        {
            "type": "call.update",
            "call_id": "cal_x",
            "media": ["audio"],
            "muted": True,
        },
        user_id="usr_caller",
        redis=redis,
    )

    _, payload = bus.sent[0]
    assert payload["muted"] is True
    assert payload["media"] == ["audio"]
