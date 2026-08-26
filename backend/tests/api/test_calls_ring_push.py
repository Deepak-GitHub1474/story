"""Reaching a phone whose app is closed, and letting it pick up what it missed."""

import pytest_asyncio

from app.adapters.push_fcm import FcmAdapter
from app.api.endpoints.calls.ring import cancel_push, ring_push
from app.api.endpoints.calls.signaling import handle, save
from app.core.time import to_wire, utc_now
from app.ports.push import PushMessage, PushOutcome


class FakePush:
    def __init__(self, stale: tuple[str, ...] = ()):
        self.sent: list[PushMessage] = []
        self._stale = stale

    async def send(self, messages):
        self.sent.extend(messages)
        return PushOutcome(
            delivered=tuple(m.token for m in messages), stale=self._stale
        )


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


@pytest_asyncio.fixture
async def redis(app_instance):
    return app_instance.state.redis


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
            "caller_profile": {
                "user_id": "usr_caller",
                "username": "ann",
                "display_name": "Ann",
            },
        },
        redis,
        45,
    )


async def a_device(mongo, user_id="usr_callee", token=None):
    token = token or "tok_1"
    await mongo["push_tokens"].insert_one(
        {"_id": token, "user_id": user_id, "token": token}
    )


def test_a_call_push_carries_no_notification_block():
    """A notification block would make FCM draw it. A call must reach the app itself."""
    envelope = FcmAdapter.__dict__["_envelope"](
        FcmAdapter.__new__(FcmAdapter),
        PushMessage(token="t", title="", body="", data={"kind": "call"}, data_only=True),
    )

    assert "notification" not in envelope["message"]
    assert envelope["message"]["android"]["priority"] == "high"
    assert envelope["message"]["data"]["kind"] == "call"


def test_an_ordinary_push_still_has_one():
    envelope = FcmAdapter.__dict__["_envelope"](
        FcmAdapter.__new__(FcmAdapter),
        PushMessage(token="t", title="Hi", body="There", data={}),
    )

    assert envelope["message"]["notification"]["title"] == "Hi"


async def test_a_ring_reaches_every_device_the_person_owns(mongo):
    await a_device(mongo, token="tok_1")
    await a_device(mongo, token="tok_2")
    push = FakePush()

    sent = await ring_push(
        callee_id="usr_callee",
        call_id="cal_x",
        caller={"display_name": "Ann", "user_id": "usr_caller"},
        mongo=mongo,
        push=push,
    )

    assert sent == 2
    assert {message.token for message in push.sent} == {"tok_1", "tok_2"}
    assert all(message.data_only for message in push.sent)


async def test_the_ring_says_who_is_calling(mongo):
    await a_device(mongo)
    push = FakePush()

    await ring_push(
        callee_id="usr_callee",
        call_id="cal_x",
        caller={"display_name": "Ann", "user_id": "usr_caller"},
        mongo=mongo,
        push=push,
    )

    data = push.sent[0].data
    assert data["kind"] == "call"
    assert data["call_id"] == "cal_x"
    assert data["caller_name"] == "Ann"


async def test_a_person_with_no_device_is_simply_not_pushed(mongo):
    push = FakePush()

    assert await ring_push(
        callee_id="usr_nobody",
        call_id="cal_x",
        caller={},
        mongo=mongo,
        push=push,
    ) == 0
    assert push.sent == []


async def test_a_dead_token_is_forgotten(mongo):
    await a_device(mongo, token="tok_dead")
    push = FakePush(stale=("tok_dead",))

    await ring_push(
        callee_id="usr_callee", call_id="cal_x", caller={}, mongo=mongo, push=push
    )

    assert await mongo["push_tokens"].count_documents({"token": "tok_dead"}) == 0


async def test_cancelling_tells_the_phone_to_stop_ringing(mongo):
    await a_device(mongo)
    push = FakePush()

    await cancel_push(
        callee_id="usr_callee", call_id="cal_x", mongo=mongo, push=push
    )

    assert push.sent[0].data == {"kind": "call_cancelled", "call_id": "cal_x"}


async def test_the_offer_is_kept_so_a_woken_phone_can_fetch_it(
    ringing, redis, mongo, monkeypatch
):
    """A push wakes the app after the offer was already relayed. It must still exist."""
    monkeypatch.setattr(
        "app.api.endpoints.calls.signaling.bus",
        type("B", (), {"publish": staticmethod(lambda *a, **k: _noop())})(),
    )

    await handle(
        {"type": "call.offer", "call_id": "cal_x", "sdp": "v=0 real", "media": ["audio"]},
        user_id="usr_caller",
        redis=redis,
        mongo=mongo,
    )

    from app.api.endpoints.calls.signaling import load

    assert (await load("cal_x", redis))["offer_sdp"] == "v=0 real"


async def _noop():
    return None


async def test_the_callee_can_fetch_the_call_it_missed(client, signup_payload, redis):
    tokens = (await client.post("/v1/auth/signup", json=signup_payload)).json()["data"][
        "tokens"
    ]
    headers = {"authorization": f"Bearer {tokens['access_token']}"}
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"][
        "user_id"
    ]

    await save(
        "cal_y",
        {
            "call_id": "cal_y",
            "caller": "usr_caller",
            "callee": me,
            "conversation_id": "cnv_1",
            "started_at": to_wire(utc_now()),
            "connected_at": None,
            "offer_sdp": "v=0 waiting",
            "media": ["audio"],
            "caller_profile": {"user_id": "usr_caller", "username": "ann"},
        },
        redis,
        45,
    )

    response = await client.get("/v1/calls/cal_y/pending", headers=headers)

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["sdp"] == "v=0 waiting"
    assert data["peer"]["username"] == "ann"
    assert data["ice_servers"]


async def test_nobody_else_can_fetch_your_incoming_call(client, signup_payload, redis):
    tokens = (await client.post("/v1/auth/signup", json=signup_payload)).json()["data"][
        "tokens"
    ]
    headers = {"authorization": f"Bearer {tokens['access_token']}"}

    await save(
        "cal_z",
        {
            "call_id": "cal_z",
            "caller": "usr_caller",
            "callee": "usr_someone_else",
            "conversation_id": "cnv_1",
            "started_at": to_wire(utc_now()),
            "connected_at": None,
            "offer_sdp": "v=0 private",
            "caller_profile": {},
        },
        redis,
        45,
    )

    response = await client.get("/v1/calls/cal_z/pending", headers=headers)

    assert response.status_code == 404
    assert response.json()["data"]["code"] == "CALL_NOT_FOUND"


async def test_a_call_that_already_ended_cannot_be_fetched(client, signup_payload):
    tokens = (await client.post("/v1/auth/signup", json=signup_payload)).json()["data"][
        "tokens"
    ]
    headers = {"authorization": f"Bearer {tokens['access_token']}"}

    response = await client.get("/v1/calls/cal_gone/pending", headers=headers)

    assert response.status_code == 404
