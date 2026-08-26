# Voice Calling — Backend and Relay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the server half of 1:1 voice calling — call setup, six signaling message types, ephemeral TURN credentials, per-participant call history with real deletes and configurable auto-delete, and a coturn relay — so the Flutter client has a complete, tested API to build against.

**Architecture:** Signaling rides the WebSocket hub that already exists (`app/realtime/hub.py`, Redis-fanned via `app/realtime/bus.py`); no new transport. Call setup is one REST call that validates the conversation and mints short-lived TURN credentials. Ringing state lives in Redis with a TTL and never reaches MongoDB. History writes two rows per call — one per participant — so each side owns its own retention and deletions.

**Tech Stack:** Python 3.13, FastAPI, Motor/MongoDB 8, Redis 7, coturn, pytest + pytest-asyncio, ruff.

**Spec:** `docs/17-voice-calling.md`

## Global Constraints

- **No comments and no docstrings in `backend/app/`.** Reasoning belongs in `docs/`. Test files may carry docstrings. (`docs/02-repo-structure-and-conventions.md` §5a)
- **No production code without a failing test first.**
- **One response shape:** every endpoint returns `ok_response(message, data)`. `ok_response` raises unless `message` is a sentence ending in `.`, `!`, or `?`.
- **Error codes are SCREAMING_SNAKE_CASE** and must be registered in `ERROR_SPEC` in `app/core/errors.py` with an HTTP status and a plain-language message.
- **Deletion is real deletion** — `delete_many`, never a `deleted_at` flag, for call rows.
- **`media` is always a list**, never a boolean. `["audio"]` today.
- **No new Python dependencies.** TURN credentials use `hmac`/`hashlib` from the standard library.
- **Do not commit or push until the repository owner says "commit and push".** Steps below include commit commands; run them only under that standing instruction.
- Run `make check` (ruff + pytest) from `backend/` before every commit.

---

## File Structure

| File | Responsibility |
|---|---|
| `app/api/endpoints/calls/constants.py` | Collection names, states, outcomes, limits |
| `app/api/endpoints/calls/models.py` | Pydantic request bodies |
| `app/api/endpoints/calls/controllers.py` | Call setup, history read, deletes |
| `app/api/endpoints/calls/router.py` | Route definitions |
| `app/api/endpoints/calls/signaling.py` | The six socket message handlers |
| `app/adapters/turn.py` | Ephemeral TURN credential minting |
| `app/workers/call_sweep.py` | Retention sweep |
| `app/db/indexes.py` | `calls` indexes |
| `app/workers/scheduler.py` | One row in `jobs()` |
| `app/config.py` | TURN and call settings |
| `app/core/errors.py` | Two new error codes |
| `app/api/router.py` | Register the calls router |
| `app/api/endpoints/realtime/router.py` | Dispatch `call.*` to signaling |

---

### Task 1: Ephemeral TURN credentials

A static TURN secret compiled into a public APK is an open relay billed to us. coturn's REST auth accepts a username of `<expiry-unix>:<user-id>` and a password of `base64(hmac_sha1(secret, username))`, valid until the expiry.

**Files:**
- Create: `app/adapters/turn.py`
- Modify: `app/config.py`
- Test: `tests/adapters/test_turn.py`

**Interfaces:**
- Consumes: `Settings.TURN_SHARED_SECRET`, `Settings.TURN_URLS`, `Settings.TURN_CREDENTIAL_TTL_SECONDS`
- Produces: `ice_servers(user_id: str, *, settings: Settings, now: datetime | None = None) -> list[dict[str, Any]]`

- [ ] **Step 1: Write the failing test**

```python
"""Credentials a public APK may carry, because they expire before they are worth stealing."""

import base64
import hashlib
import hmac
from datetime import timedelta

from app.adapters.turn import ice_servers
from app.config import Settings
from app.core.time import utc_now

SECRET = "a-test-turn-secret"


def settings() -> Settings:
    return Settings(
        TURN_SHARED_SECRET=SECRET,
        TURN_URLS="turn:relay.example.org:3478,turns:relay.example.org:443?transport=tcp",
        TURN_CREDENTIAL_TTL_SECONDS=300,
    )


def test_the_username_carries_its_own_expiry():
    now = utc_now()

    servers = ice_servers("usr_alice", settings=settings(), now=now)

    turn = [s for s in servers if s["urls"][0].startswith("turn")][0]
    expiry, user_id = turn["username"].split(":", 1)
    assert user_id == "usr_alice"
    assert int(expiry) == int((now + timedelta(seconds=300)).timestamp())


def test_the_password_is_an_hmac_of_the_username():
    servers = ice_servers("usr_alice", settings=settings())

    turn = [s for s in servers if s["urls"][0].startswith("turn")][0]
    expected = base64.b64encode(
        hmac.new(SECRET.encode(), turn["username"].encode(), hashlib.sha1).digest()
    ).decode()
    assert turn["credential"] == expected


def test_every_configured_relay_url_is_offered():
    servers = ice_servers("usr_alice", settings=settings())

    turn = [s for s in servers if s["urls"][0].startswith("turn")][0]
    assert turn["urls"] == [
        "turn:relay.example.org:3478",
        "turns:relay.example.org:443?transport=tcp",
    ]


def test_a_stun_server_is_always_offered_so_most_calls_never_relay():
    servers = ice_servers("usr_alice", settings=settings())

    assert any(s["urls"][0].startswith("stun:") for s in servers)


def test_no_relay_is_offered_when_none_is_configured():
    bare = Settings(TURN_SHARED_SECRET="", TURN_URLS="")

    servers = ice_servers("usr_alice", settings=bare)

    assert all(s["urls"][0].startswith("stun:") for s in servers)


def test_two_users_never_share_a_credential():
    config = settings()

    alice = ice_servers("usr_alice", settings=config)[1]["credential"]
    bob = ice_servers("usr_bob", settings=config)[1]["credential"]

    assert alice != bob
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/adapters/test_turn.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.adapters.turn'`

- [ ] **Step 3: Add the settings**

In `app/config.py`, beside the other adapter settings:

```python
    TURN_SHARED_SECRET: str = ""
    TURN_URLS: str = ""
    TURN_CREDENTIAL_TTL_SECONDS: int = 300
    STUN_URL: str = "stun:stun.l.google.com:19302"
```

- [ ] **Step 4: Write the implementation**

Create `app/adapters/turn.py`:

```python
import base64
import hashlib
import hmac
from datetime import datetime, timedelta
from typing import Any

from app.config import Settings
from app.core.time import utc_now


def _relay_urls(settings: Settings) -> list[str]:
    return [url.strip() for url in settings.TURN_URLS.split(",") if url.strip()]


def ice_servers(
    user_id: str, *, settings: Settings, now: datetime | None = None
) -> list[dict[str, Any]]:
    servers: list[dict[str, Any]] = [{"urls": [settings.STUN_URL]}]

    urls = _relay_urls(settings)
    if not urls or not settings.TURN_SHARED_SECRET:
        return servers

    moment = now or utc_now()
    expiry = int((moment + timedelta(seconds=settings.TURN_CREDENTIAL_TTL_SECONDS)).timestamp())
    username = f"{expiry}:{user_id}"
    digest = hmac.new(
        settings.TURN_SHARED_SECRET.encode(), username.encode(), hashlib.sha1
    ).digest()

    servers.append(
        {
            "urls": urls,
            "username": username,
            "credential": base64.b64encode(digest).decode(),
        }
    )
    return servers
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/adapters/test_turn.py -v`
Expected: 6 passed

- [ ] **Step 6: Commit**

```bash
git add backend/app/adapters/turn.py backend/app/config.py backend/tests/adapters/test_turn.py
git commit -m "feat(calls): mint TURN credentials that expire before they are worth stealing"
```

---

### Task 2: Start a call

`POST /v1/calls` is the only REST step in placing a call. It proves the caller may ring this person, allocates the `call_id`, and hands back ICE servers.

**Files:**
- Create: `app/api/endpoints/calls/__init__.py`, `constants.py`, `models.py`, `controllers.py`, `router.py`
- Modify: `app/core/errors.py`, `app/api/router.py`, `app/config.py`, `app/core/ids.py`
- Test: `tests/api/test_calls_start.py`

**Interfaces:**
- Consumes: `ice_servers` from Task 1
- Produces: `start_call(body, *, claims, mongo, redis) -> dict` returning `{"call_id": str, "conversation_id": str, "peer": {...}, "ice_servers": [...], "ring_timeout_seconds": int}`; constants `CALLS = "calls"`, `RING_PREFIX = "ST:CALL:"`

- [ ] **Step 1: Write the failing test**

```python
"""Who may ring whom, and what the caller gets back."""

import pytest
import pytest_asyncio

from app.api.endpoints.chat import constants as chat_c


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def auth(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def a_pair(client, mongo, first, second, *, state=chat_c.ACCEPTED):
    """Two accounts and a conversation between them in the given state."""
    headers_a = await auth(client, first)
    headers_b = await auth(client, second)
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
    return headers_a, headers_b, a["_id"], b["_id"]


@pytest.fixture
def other_payload(unique_username):
    return {
        "username": f"{unique_username}_two",
        "password": "Str0ngPassphrase!42",
        "tnc_accepted": True,
    }


async def test_a_call_into_an_accepted_conversation_is_allowed(
    client, signup_payload, other_payload, mongo
):
    headers, _, _, _ = await a_pair(client, mongo, signup_payload, other_payload)

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers
    )

    assert response.status_code == 201
    data = response.json()["data"]
    assert data["call_id"].startswith("cal_")
    assert data["ice_servers"]
    assert data["ring_timeout_seconds"] == 45


async def test_a_call_into_a_pending_conversation_is_refused(
    client, signup_payload, other_payload, mongo
):
    """A request to talk is not consent to be rung."""
    headers, _, _, _ = await a_pair(
        client, mongo, signup_payload, other_payload, state=chat_c.PENDING
    )

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "CALL_NOT_ALLOWED"


async def test_a_call_into_someone_elses_conversation_is_refused(
    client, signup_payload, other_payload, mongo
):
    await a_pair(client, mongo, signup_payload, other_payload)
    outsider = await auth(
        client,
        {
            "username": f"{signup_payload['username']}_three",
            "password": "Str0ngPassphrase!42",
            "tnc_accepted": True,
        },
    )

    response = await client.post(
        "/v1/calls", json={"conversation_id": "cnv_pair"}, headers=outsider
    )

    assert response.status_code == 404
    assert response.json()["data"]["code"] == "CONVERSATION_NOT_FOUND"


async def test_a_blocked_person_cannot_be_rung(
    client, signup_payload, other_payload, mongo
):
    headers, _, caller, callee = await a_pair(client, mongo, signup_payload, other_payload)
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
    headers, _, _, _ = await a_pair(client, mongo, signup_payload, other_payload)

    data = (
        await client.post("/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers)
    ).json()["data"]

    assert await mongo["calls"].count_documents({}) == 0
    assert await app_instance.state.redis.get(f"ST:CALL:{data['call_id']}") is not None


async def test_the_caller_learns_who_they_are_ringing(
    client, signup_payload, other_payload, mongo
):
    headers, _, _, _ = await a_pair(client, mongo, signup_payload, other_payload)

    data = (
        await client.post("/v1/calls", json={"conversation_id": "cnv_pair"}, headers=headers)
    ).json()["data"]

    assert data["peer"]["username"] == other_payload["username"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/api/test_calls_start.py -v`
Expected: FAIL — all six 404, because `/v1/calls` does not exist

- [ ] **Step 3: Add error codes**

In `app/core/errors.py`, add to `ErrorCode`:

```python
    CALL_NOT_ALLOWED = "CALL_NOT_ALLOWED"
    CALL_NOT_FOUND = "CALL_NOT_FOUND"
```

and to `ERROR_SPEC`:

```python
    ErrorCode.CALL_NOT_ALLOWED: (403, "You cannot call this person."),
    ErrorCode.CALL_NOT_FOUND: (404, "We could not find that call."),
```

- [ ] **Step 4: Add the call settings**

In `app/config.py`:

```python
    CALL_RING_TIMEOUT_SECONDS: int = 45
    CALL_HISTORY_RETENTION_DAYS: int = 30
```

- [ ] **Step 5: Register the two new id prefixes**

`new_id` raises `ValueError` on any prefix not in its allowlist, so this must
happen before either id is minted. In `app/core/ids.py`, add to `ID_PREFIXES`:

```python
        "cal",
        "chi",
```

`cal` is a call. `chi` is one person's history row for a call — two are written
per call, so they cannot share the call's id.

- [ ] **Step 6: Write the constants and models**

Create `app/api/endpoints/calls/__init__.py` (empty file).

Create `app/api/endpoints/calls/constants.py`:

```python
CALLS = "calls"
CONVERSATIONS = "chat_conversations"
CONNECTIONS = "connections"
USERS = "users"

RING_PREFIX = "ST:CALL:"

AUDIO = "audio"

ANSWERED = "answered"
MISSED = "missed"
DECLINED = "declined"
BUSY = "busy"
FAILED = "failed"

INBOUND = "in"
OUTBOUND = "out"

HISTORY_MAX_LIMIT = 50
HISTORY_DEFAULT_LIMIT = 30
DELETE_MAX_IDS = 200
```

Create `app/api/endpoints/calls/models.py`:

```python
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class StartCallRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    conversation_id: Annotated[str, Field(min_length=1, max_length=64)]
```

- [ ] **Step 7: Write the controller**

Create `app/api/endpoints/calls/controllers.py`:

```python
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from redis.asyncio import Redis

from app.adapters.turn import ice_servers
from app.api.endpoints.calls import constants as c
from app.api.endpoints.calls.models import StartCallRequest
from app.config import get_settings
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id


async def _conversation(conversation_id: str, user_id: str, mongo: AsyncIOMotorDatabase):
    conversation = await mongo[c.CONVERSATIONS].find_one(
        {"_id": conversation_id, "participant_ids": user_id}
    )
    if conversation is None:
        raise api_error(ErrorCode.CONVERSATION_NOT_FOUND)
    return conversation


async def _blocked(first: str, second: str, mongo: AsyncIOMotorDatabase) -> bool:
    found = await mongo[c.CONNECTIONS].find_one(
        {
            "status": "blocked",
            "$or": [
                {"follower_id": first, "followee_id": second},
                {"follower_id": second, "followee_id": first},
            ],
        },
        {"_id": 1},
    )
    return found is not None


async def start_call(
    body: StartCallRequest, *, claims, mongo: AsyncIOMotorDatabase, redis: Redis
) -> dict[str, Any]:
    settings = get_settings()
    conversation = await _conversation(body.conversation_id, claims.user_id, mongo)

    if conversation.get("state") != "accepted":
        raise api_error(ErrorCode.CALL_NOT_ALLOWED)

    peer_id = next(
        person for person in conversation["participant_ids"] if person != claims.user_id
    )
    if await _blocked(claims.user_id, peer_id, mongo):
        raise api_error(ErrorCode.CALL_NOT_ALLOWED)

    peer = await mongo[c.USERS].find_one(
        {"_id": peer_id}, {"username": 1, "display_name": 1, "avatar_seed": 1}
    )
    if peer is None:
        raise api_error(ErrorCode.CALL_NOT_ALLOWED)

    call_id = new_id("cal")
    await redis.set(
        f"{c.RING_PREFIX}{call_id}",
        f"{claims.user_id}:{peer_id}:{body.conversation_id}",
        ex=settings.CALL_RING_TIMEOUT_SECONDS,
    )

    return {
        "call_id": call_id,
        "conversation_id": body.conversation_id,
        "media": [c.AUDIO],
        "peer": {
            "user_id": peer["_id"],
            "username": peer["username"],
            "display_name": peer.get("display_name") or peer["username"],
            "avatar_seed": peer.get("avatar_seed"),
        },
        "ice_servers": ice_servers(claims.user_id, settings=settings),
        "ring_timeout_seconds": settings.CALL_RING_TIMEOUT_SECONDS,
    }
```

- [ ] **Step 8: Write the router and register it**

Create `app/api/endpoints/calls/router.py`:

```python
from fastapi import APIRouter, Depends, status

from app.api.endpoints.calls import controllers
from app.api.endpoints.calls.models import StartCallRequest
from app.core.deps import CurrentClaims, MongoDatabase, rate_limit_dep
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/calls", tags=["calls"])


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("call_start", 30, 3600))],
)
async def start_call(
    body: StartCallRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.start_call(body, claims=claims, mongo=mongo, redis=redis)
    return ok_response("Ringing.", data=data)
```

In `app/api/router.py`, add the import beside the others and register it:

```python
from app.api.endpoints.calls.router import router as calls_router
...
api_router.include_router(calls_router)
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_calls_start.py -v`
Expected: 6 passed

- [ ] **Step 10: Run the whole suite**

Run: `cd backend && make check`
Expected: ruff clean, all tests pass

- [ ] **Step 11: Commit**

```bash
git add backend/app/api/endpoints/calls backend/app/api/router.py backend/app/core/errors.py backend/app/config.py backend/tests/api/test_calls_start.py
git commit -m "feat(calls): let one person ring another they already talk to"
```

---

### Task 3: The six signaling messages

Signaling relays opaque SDP and ICE between two people. The server never parses the media description — it checks that the sender is party to the call and forwards.

**Files:**
- Create: `app/api/endpoints/calls/signaling.py`
- Modify: `app/api/endpoints/realtime/router.py`
- Test: `tests/api/test_calls_signaling.py`

**Interfaces:**
- Consumes: `RING_PREFIX` from Task 2, `app.realtime.bus.publish`
- Produces: `handle(event: dict, *, user_id: str, redis: Redis) -> None`, `SIGNAL_TYPES: frozenset[str]`

- [ ] **Step 1: Write the failing test**

```python
"""Relaying an offer without reading it, and refusing to relay for strangers."""

import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.api.endpoints.calls.signaling import SIGNAL_TYPES, handle


class FakeBus:
    def __init__(self):
        self.sent: list[tuple[list[str], dict]] = []

    async def publish(self, redis, user_ids, payload):
        self.sent.append((user_ids, payload))


@pytest_asyncio.fixture
async def redis(app_instance):
    return app_instance.state.redis


@pytest_asyncio.fixture
async def ringing(redis):
    await redis.set(f"{c.RING_PREFIX}cal_x", "usr_caller:usr_callee:cnv_1", ex=45)
    return "cal_x"


async def test_every_message_type_is_registered():
    assert SIGNAL_TYPES == frozenset(
        {"call.offer", "call.answer", "call.ice", "call.update", "call.end"}
    )


async def test_an_offer_reaches_the_other_person(ringing, redis, monkeypatch):
    bus = FakeBus()
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", bus)

    await handle(
        {"type": "call.offer", "call_id": "cal_x", "sdp": "v=0...", "media": ["audio"]},
        user_id="usr_caller",
        redis=redis,
    )

    targets, payload = bus.sent[0]
    assert targets == ["usr_callee"]
    assert payload["type"] == "call.offer"
    assert payload["sdp"] == "v=0..."


async def test_the_answer_goes_back_to_the_caller(ringing, redis, monkeypatch):
    bus = FakeBus()
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", bus)

    await handle(
        {"type": "call.answer", "call_id": "cal_x", "sdp": "v=0..."},
        user_id="usr_callee",
        redis=redis,
    )

    targets, _ = bus.sent[0]
    assert targets == ["usr_caller"]


async def test_a_stranger_cannot_inject_into_a_call(ringing, redis, monkeypatch):
    """Knowing a call_id must not be enough to join it."""
    bus = FakeBus()
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", bus)

    await handle(
        {"type": "call.ice", "call_id": "cal_x", "candidate": "candidate:1"},
        user_id="usr_eavesdropper",
        redis=redis,
    )

    assert bus.sent == []


async def test_signaling_for_an_expired_call_goes_nowhere(redis, monkeypatch):
    bus = FakeBus()
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", bus)

    await handle(
        {"type": "call.ice", "call_id": "cal_gone", "candidate": "candidate:1"},
        user_id="usr_caller",
        redis=redis,
    )

    assert bus.sent == []


async def test_ending_a_call_clears_the_ring(ringing, redis, monkeypatch):
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", FakeBus())

    await handle(
        {"type": "call.end", "call_id": "cal_x", "reason": "hangup"},
        user_id="usr_caller",
        redis=redis,
    )

    assert await redis.get(f"{c.RING_PREFIX}cal_x") is None


async def test_an_update_carries_media_so_video_needs_no_new_message(
    ringing, redis, monkeypatch
):
    bus = FakeBus()
    monkeypatch.setattr("app.api.endpoints.calls.signaling.bus", bus)

    await handle(
        {
            "type": "call.update",
            "call_id": "cal_x",
            "media": ["audio", "video"],
            "sdp": "v=0...",
        },
        user_id="usr_caller",
        redis=redis,
    )

    _, payload = bus.sent[0]
    assert payload["media"] == ["audio", "video"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/api/test_calls_signaling.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.api.endpoints.calls.signaling'`

- [ ] **Step 3: Write the implementation**

Create `app/api/endpoints/calls/signaling.py`:

```python
from typing import Any

from redis.asyncio import Redis

from app.api.endpoints.calls import constants as c
from app.realtime import bus

SIGNAL_TYPES = frozenset(
    {"call.offer", "call.answer", "call.ice", "call.update", "call.end"}
)

RELAYED_FIELDS = ("sdp", "candidate", "media", "reason", "conversation_id")


async def _parties(call_id: str, redis: Redis) -> tuple[str, str, str] | None:
    raw = await redis.get(f"{c.RING_PREFIX}{call_id}")
    if raw is None:
        return None
    value = raw.decode() if isinstance(raw, bytes) else str(raw)
    caller, callee, conversation_id = value.split(":", 2)
    return caller, callee, conversation_id


async def handle(event: dict[str, Any], *, user_id: str, redis: Redis) -> None:
    kind = event.get("type")
    call_id = event.get("call_id")
    if kind not in SIGNAL_TYPES or not isinstance(call_id, str):
        return

    parties = await _parties(call_id, redis)
    if parties is None:
        return

    caller, callee, _ = parties
    if user_id not in (caller, callee):
        return

    peer = callee if user_id == caller else caller

    payload: dict[str, Any] = {"type": kind, "call_id": call_id, "from": user_id}
    for field in RELAYED_FIELDS:
        if field in event:
            payload[field] = event[field]

    await bus.publish(redis, [peer], payload)

    if kind == "call.end":
        await redis.delete(f"{c.RING_PREFIX}{call_id}")
```

- [ ] **Step 4: Dispatch from the socket**

In `app/api/endpoints/realtime/router.py`, add the import:

```python
from app.api.endpoints.calls import signaling as call_signaling
```

and at the end of `_handle`, after the `typing` branch:

```python
    if kind in call_signaling.SIGNAL_TYPES:
        await call_signaling.handle(event, user_id=user_id, redis=redis)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_calls_signaling.py -v`
Expected: 7 passed

- [ ] **Step 6: Commit**

```bash
git add backend/app/api/endpoints/calls/signaling.py backend/app/api/endpoints/realtime/router.py backend/tests/api/test_calls_signaling.py
git commit -m "feat(calls): relay offers, answers and candidates between two people"
```

---

### Task 4: Write the history, two rows per call

Two people can hold different retention settings, and deleting your copy must not touch theirs. One row each.

**Files:**
- Modify: `app/api/endpoints/calls/controllers.py`, `app/api/endpoints/calls/signaling.py`, `app/db/indexes.py`
- Test: `tests/api/test_calls_history_write.py`

**Interfaces:**
- Consumes: `_parties` from Task 3
- Produces: `record_call(*, call_id, caller_id, callee_id, conversation_id, outcome, started_at, connected_at, ended_at, mongo) -> None`

- [ ] **Step 1: Write the failing test**

```python
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


async def a_call(mongo, *, outcome=c.ANSWERED, seconds=120):
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
        mongo=mongo,
    )


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
    assert row["media"] == ["audio"]


@pytest.mark.parametrize("outcome", [c.MISSED, c.DECLINED, c.BUSY, c.FAILED])
async def test_every_ending_is_recorded_not_only_the_happy_one(mongo, outcome):
    await a_call(mongo, outcome=outcome)

    assert await mongo[c.CALLS].count_documents({"outcome": outcome}) == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/api/test_calls_history_write.py -v`
Expected: FAIL with `ImportError: cannot import name 'record_call'`

- [ ] **Step 3: Write the implementation**

Append to `app/api/endpoints/calls/controllers.py`:

```python
from datetime import datetime, timedelta

from app.core.time import utc_now


def _expires_at(started_at: datetime, retention_days: int) -> datetime | None:
    if retention_days <= 0:
        return None
    return started_at + timedelta(days=retention_days)


async def _retention_days(user_id: str, mongo: AsyncIOMotorDatabase) -> int:
    settings = get_settings()
    person = await mongo[c.USERS].find_one({"_id": user_id}, {"prefs": 1})
    prefs = (person or {}).get("prefs") or {}
    value = prefs.get("call_history_days")
    if isinstance(value, int):
        return value
    return settings.CALL_HISTORY_RETENTION_DAYS


async def record_call(
    *,
    call_id: str,
    caller_id: str,
    callee_id: str,
    conversation_id: str,
    outcome: str,
    started_at: datetime,
    connected_at: datetime | None,
    ended_at: datetime,
    relayed: bool = False,
    mongo: AsyncIOMotorDatabase,
) -> None:
    duration = 0
    if connected_at is not None:
        duration = max(0, int((ended_at - connected_at).total_seconds()))

    rows = []
    for owner_id, peer_id, direction in (
        (caller_id, callee_id, c.OUTBOUND),
        (callee_id, caller_id, c.INBOUND),
    ):
        rows.append(
            {
                "_id": new_id("chi"),
                "call_id": call_id,
                "owner_id": owner_id,
                "peer_id": peer_id,
                "conversation_id": conversation_id,
                "direction": direction,
                "outcome": outcome,
                "media": [c.AUDIO],
                "relayed": relayed,
                "started_at": started_at,
                "connected_at": connected_at,
                "ended_at": ended_at,
                "duration_seconds": duration,
                "expires_at": _expires_at(
                    started_at, await _retention_days(owner_id, mongo)
                ),
            }
        )

    await mongo[c.CALLS].insert_many(rows)
```

- [ ] **Step 4: Add the indexes**

In `app/db/indexes.py`, add to `INDEXES`:

```python
    "calls": [
        IndexSpec(
            [("owner_id", ASCENDING), ("started_at", DESCENDING)],
            "ix_owner_time",
        ),
        IndexSpec(
            [("expires_at", ASCENDING)],
            "ix_expiry",
            partial={"expires_at": {"$type": "date"}},
        ),
        IndexSpec([("call_id", ASCENDING)], "ix_call"),
    ],
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_calls_history_write.py -v`
Expected: 9 passed

- [ ] **Step 6: Commit**

```bash
git add backend/app/api/endpoints/calls/controllers.py backend/app/db/indexes.py backend/tests/api/test_calls_history_write.py
git commit -m "feat(calls): give each person their own record of a call"
```

---

### Task 5: Read the history

**Files:**
- Modify: `app/api/endpoints/calls/controllers.py`, `app/api/endpoints/calls/router.py`
- Test: `tests/api/test_calls_history_read.py`

**Interfaces:**
- Consumes: `record_call` from Task 4
- Produces: `list_calls(*, claims, mongo, limit, cursor) -> dict` returning `{"items": [...], "next_cursor": str | None, "has_more": bool}`

- [ ] **Step 1: Write the failing test**

```python
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


async def seed(mongo, owner_id, count, *, peer="usr_peer"):
    now = utc_now()
    await mongo[c.CALLS].insert_many(
        [
            {
                "_id": f"chi_{owner_id}_{index}",
                "call_id": f"cal_{index}",
                "owner_id": owner_id,
                "peer_id": peer,
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


async def me(client, mongo, payload):
    headers = await auth(client, payload)
    person = await mongo["users"].find_one(
        {"username_lower": payload["username"].lower()}, {"_id": 1}
    )
    return headers, person["_id"]


async def test_the_newest_call_is_first(client, signup_payload, mongo):
    headers, user_id = await me(client, mongo, signup_payload)
    await seed(mongo, user_id, 3)

    items = (await client.get("/v1/calls", headers=headers)).json()["data"]["items"]

    assert [item["call_id"] for item in items] == ["cal_0", "cal_1", "cal_2"]


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

    ids = [item["call_id"] for item in first["items"]] + [
        item["call_id"] for item in second["items"]
    ]
    assert len(ids) == len(set(ids))


async def test_an_empty_history_is_not_an_error(client, signup_payload):
    headers = await auth(client, signup_payload)

    response = await client.get("/v1/calls", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["items"] == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/api/test_calls_history_read.py -v`
Expected: FAIL — 404, `GET /v1/calls` does not exist

- [ ] **Step 3: Write the controller**

Append to `app/api/endpoints/calls/controllers.py`:

```python
def _wire(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "call_id": row["call_id"],
        "peer_id": row["peer_id"],
        "conversation_id": row["conversation_id"],
        "direction": row["direction"],
        "outcome": row["outcome"],
        "media": row["media"],
        "started_at": row["started_at"].isoformat().replace("+00:00", "Z"),
        "duration_seconds": row["duration_seconds"],
    }


async def list_calls(
    *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    capped = max(1, min(limit, c.HISTORY_MAX_LIMIT))
    query: dict[str, Any] = {"owner_id": claims.user_id}
    if cursor:
        query["_id"] = {"$lt": cursor}

    rows = (
        await mongo[c.CALLS]
        .find(query)
        .sort([("started_at", -1), ("_id", -1)])
        .limit(capped + 1)
        .to_list(length=capped + 1)
    )

    has_more = len(rows) > capped
    page = rows[:capped]
    return {
        "items": [_wire(row) for row in page],
        "next_cursor": page[-1]["_id"] if has_more and page else None,
        "has_more": has_more,
    }
```

- [ ] **Step 4: Add the route**

In `app/api/endpoints/calls/router.py`:

```python
from fastapi import Query

from app.api.endpoints.calls import constants as c


@router.get("", status_code=status.HTTP_200_OK)
async def list_calls(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = Query(default=c.HISTORY_DEFAULT_LIMIT, ge=1, le=c.HISTORY_MAX_LIMIT),
    cursor: str | None = Query(default=None),
):
    data = await controllers.list_calls(
        claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("Your calls.", data=data)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_calls_history_read.py -v`
Expected: 5 passed

- [ ] **Step 6: Commit**

```bash
git add backend/app/api/endpoints/calls backend/tests/api/test_calls_history_read.py
git commit -m "feat(calls): show a person their own call history"
```

---

### Task 6: Delete the history

Deleting a call row erases it. There is nothing in object storage behind it, so a real delete is the whole job.

**Files:**
- Modify: `app/api/endpoints/calls/controllers.py`, `app/api/endpoints/calls/models.py`, `app/api/endpoints/calls/router.py`
- Test: `tests/api/test_calls_delete.py`

**Interfaces:**
- Consumes: `list_calls` from Task 5
- Produces: `delete_calls(body, *, claims, mongo) -> dict` returning `{"deleted": int}`

- [ ] **Step 1: Write the failing test**

```python
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


async def seed(mongo, owner_id, ids):
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
            for call_id in ids
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


async def test_you_cannot_delete_a_stranger_out_of_their_own_history(
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/api/test_calls_delete.py -v`
Expected: FAIL — 404 on both routes

- [ ] **Step 3: Add the request model**

Append to `app/api/endpoints/calls/models.py`:

```python
class DeleteCallsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    call_ids: Annotated[list[str], Field(default_factory=list, max_length=200)]
    all: bool = False
```

- [ ] **Step 4: Write the controller**

Append to `app/api/endpoints/calls/controllers.py`:

```python
from app.api.endpoints.calls.models import DeleteCallsRequest


async def delete_calls(
    body: DeleteCallsRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    query: dict[str, Any] = {"owner_id": claims.user_id}
    if not body.all:
        if not body.call_ids:
            return {"deleted": 0}
        query["call_id"] = {"$in": body.call_ids[: c.DELETE_MAX_IDS]}

    result = await mongo[c.CALLS].delete_many(query)
    return {"deleted": result.deleted_count}


async def delete_call(call_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    result = await mongo[c.CALLS].delete_many(
        {"owner_id": claims.user_id, "call_id": call_id}
    )
    return {"deleted": result.deleted_count}
```

- [ ] **Step 5: Add the routes**

In `app/api/endpoints/calls/router.py`:

```python
from app.api.endpoints.calls.models import DeleteCallsRequest


@router.delete("/{call_id}", status_code=status.HTTP_200_OK)
async def delete_call(call_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.delete_call(call_id, claims=claims, mongo=mongo)
    return ok_response("Gone from your history.", data=data)


@router.post("/delete", status_code=status.HTTP_200_OK)
async def delete_calls(
    body: DeleteCallsRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.delete_calls(body, claims=claims, mongo=mongo)
    return ok_response("Gone from your history.", data=data)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_calls_delete.py -v`
Expected: 6 passed

- [ ] **Step 7: Commit**

```bash
git add backend/app/api/endpoints/calls backend/tests/api/test_calls_delete.py
git commit -m "feat(calls): let a person erase their call history, one or all"
```

---

### Task 7: Retention setting, and restamping when it changes

Shortening retention must reach history already recorded. Keeping old rows under the old rule is not what a privacy control should do.

**Files:**
- Modify: `app/api/endpoints/calls/controllers.py`, `app/api/endpoints/calls/models.py`, `app/api/endpoints/calls/router.py`
- Test: `tests/api/test_calls_retention.py`

**Interfaces:**
- Consumes: `_expires_at`, `_retention_days` from Task 4
- Produces: `set_retention(body, *, claims, mongo) -> dict` returning `{"call_history_days": int, "restamped": int}`

- [ ] **Step 1: Write the failing test**

```python
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


async def seed(mongo, owner_id, started_at):
    await mongo[c.CALLS].insert_one(
        {
            "_id": "chi_one",
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

    await client.put("/v1/calls/retention", json={"days": 7}, headers=headers)

    person = await mongo["users"].find_one({"_id": user_id}, {"prefs": 1})
    assert person["prefs"]["call_history_days"] == 7


async def test_changing_your_setting_never_touches_another_persons_rows(
    client, signup_payload, mongo
):
    headers, _ = await me(client, mongo, signup_payload)
    started = utc_now()
    await mongo[c.CALLS].insert_one(
        {
            "_id": "chi_theirs",
            "call_id": "cal_a",
            "owner_id": "usr_peer",
            "peer_id": "usr_other",
            "conversation_id": "cnv_1",
            "direction": c.INBOUND,
            "outcome": c.ANSWERED,
            "media": [c.AUDIO],
            "relayed": False,
            "started_at": started,
            "connected_at": started,
            "ended_at": started,
            "duration_seconds": 30,
            "expires_at": started + timedelta(days=30),
        }
    )

    await client.put("/v1/calls/retention", json={"days": 1}, headers=headers)

    row = await mongo[c.CALLS].find_one({"_id": "chi_theirs"})
    assert row["expires_at"] == started + timedelta(days=30)


@pytest.mark.parametrize("days", [-1, 400])
async def test_a_nonsense_retention_is_refused(client, signup_payload, days):
    headers = await auth(client, signup_payload)

    response = await client.put("/v1/calls/retention", json={"days": days}, headers=headers)

    assert response.status_code == 422
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/api/test_calls_retention.py -v`
Expected: FAIL — 404 on `/v1/calls/retention`

- [ ] **Step 3: Add the request model**

Append to `app/api/endpoints/calls/models.py`:

```python
class RetentionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    days: Annotated[int, Field(ge=0, le=365)]
```

- [ ] **Step 4: Write the controller**

Append to `app/api/endpoints/calls/controllers.py`:

```python
from app.api.endpoints.calls.models import RetentionRequest


async def set_retention(
    body: RetentionRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    await mongo[c.USERS].update_one(
        {"_id": claims.user_id}, {"$set": {"prefs.call_history_days": body.days}}
    )

    restamped = 0
    async for row in mongo[c.CALLS].find({"owner_id": claims.user_id}, {"started_at": 1}):
        await mongo[c.CALLS].update_one(
            {"_id": row["_id"]},
            {"$set": {"expires_at": _expires_at(row["started_at"], body.days)}},
        )
        restamped += 1

    return {"call_history_days": body.days, "restamped": restamped}
```

- [ ] **Step 5: Add the route**

In `app/api/endpoints/calls/router.py`:

```python
from app.api.endpoints.calls.models import RetentionRequest


@router.put("/retention", status_code=status.HTTP_200_OK)
async def set_retention(
    body: RetentionRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.set_retention(body, claims=claims, mongo=mongo)
    return ok_response("Saved.", data=data)
```

Register this route **before** `@router.delete("/{call_id}")` in the file, or `retention` is captured as a `call_id`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/api/test_calls_retention.py -v`
Expected: 6 passed

- [ ] **Step 7: Commit**

```bash
git add backend/app/api/endpoints/calls backend/tests/api/test_calls_retention.py
git commit -m "feat(calls): let a person choose how long their calls are remembered"
```

---

### Task 8: The retention sweeper

**Files:**
- Create: `app/workers/call_sweep.py`
- Modify: `app/workers/scheduler.py`
- Test: `tests/workers/test_call_sweep.py`

**Interfaces:**
- Consumes: `CALLS`, `expires_at` written in Tasks 4 and 7
- Produces: `sweep_expired_calls(*, mongo) -> int`; `scheduler._sweep_calls(mongo) -> int`; job name `"call_sweep"`

- [ ] **Step 1: Write the failing test**

```python
"""Rows past their expiry, and the rows that must survive."""

from datetime import timedelta

import pytest_asyncio

from app.api.endpoints.calls import constants as c
from app.core.time import utc_now
from app.workers.call_sweep import sweep_expired_calls


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def row(mongo, _id, expires_at):
    now = utc_now()
    await mongo[c.CALLS].insert_one(
        {
            "_id": _id,
            "call_id": _id,
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
    await row(mongo, "chi_old", utc_now() - timedelta(minutes=1))

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 1
    assert await mongo[c.CALLS].count_documents({}) == 0


async def test_a_call_still_inside_its_window_is_left_alone(mongo):
    await row(mongo, "chi_fresh", utc_now() + timedelta(days=5))

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 0
    assert await mongo[c.CALLS].count_documents({}) == 1


async def test_keep_forever_is_never_swept(mongo):
    await row(mongo, "chi_forever", None)

    swept = await sweep_expired_calls(mongo=mongo)

    assert swept == 0
    assert await mongo[c.CALLS].count_documents({}) == 1


async def test_the_sweep_costs_nothing_when_there_is_nothing_to_do(mongo):
    assert await sweep_expired_calls(mongo=mongo) == 0


async def test_the_scheduler_actually_runs_the_sweep(mongo, app_instance):
    """A sweeper nothing calls is a sweeper that does not exist."""
    from app.workers import scheduler

    await row(mongo, "chi_old", utc_now() - timedelta(minutes=1))

    assert "call_sweep" in [name for _, _, name in scheduler.jobs(app_instance)]
    assert await scheduler._sweep_calls(mongo) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/workers/test_call_sweep.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.workers.call_sweep'`

- [ ] **Step 3: Write the sweeper**

Create `app/workers/call_sweep.py`:

```python
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.time import utc_now
from app.logging import get_logger

logger = get_logger("story.workers.call_sweep")

CALLS = "calls"


async def sweep_expired_calls(*, mongo: AsyncIOMotorDatabase) -> int:
    result = await mongo[CALLS].delete_many(
        {"expires_at": {"$type": "date", "$lt": utc_now()}}
    )
    if result.deleted_count:
        logger.info("calls_swept", service="calls", count=result.deleted_count)
    return result.deleted_count
```

- [ ] **Step 4: Wire it into the scheduler**

In `app/workers/scheduler.py`, add the import:

```python
from app.workers.call_sweep import sweep_expired_calls
```

add the interval beside the others:

```python
CALL_SWEEP_INTERVAL_SECONDS = 3600
```

add the job function beside `_sweep_vault`:

```python
async def _sweep_calls(mongo: AsyncIOMotorDatabase) -> int:
    return await sweep_expired_calls(mongo=mongo)
```

and add one row to `jobs()`:

```python
        (CALL_SWEEP_INTERVAL_SECONDS, _sweep_calls, "call_sweep"),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && uv run pytest tests/workers/test_call_sweep.py -v`
Expected: 5 passed

- [ ] **Step 6: Run the whole suite**

Run: `cd backend && make check`
Expected: ruff clean, all tests pass

- [ ] **Step 7: Commit**

```bash
git add backend/app/workers/call_sweep.py backend/app/workers/scheduler.py backend/tests/workers/test_call_sweep.py
git commit -m "feat(calls): erase call history once it is past its keeping"
```

---

### Task 9: The coturn relay

**Files:**
- Create: `backend/coturn/turnserver.conf`, `backend/coturn/docker-compose.yml`
- Modify: `backend/.env.example`, `docs/13-deploying-the-backend.md`
- Test: manual, documented below — a relay is infrastructure and is verified against the real server

- [ ] **Step 1: Generate a relay secret**

```bash
openssl rand -hex 32
```

Put it in `backend/.env` as `TURN_SHARED_SECRET=`. It is a secret: it must never enter git, and it must never be compiled into the APK.

- [ ] **Step 2: Document the settings**

Append to `backend/.env.example`:

```
# The relay used when two phones cannot reach each other directly. Roughly
# 10-20% of mobile calls need it. TURN_SHARED_SECRET signs short-lived
# credentials, so nothing long-lived ever reaches a client.
TURN_SHARED_SECRET=replace-me-with-openssl-rand-hex-32
TURN_URLS=turn:relay.example.org:3478,turns:relay.example.org:443?transport=tcp
TURN_CREDENTIAL_TTL_SECONDS=300
STUN_URL=stun:stun.l.google.com:19302

# How long a phone rings before the call is recorded as missed.
CALL_RING_TIMEOUT_SECONDS=45

# Default lifetime of a call history row. 0 means keep forever. A person can
# change their own setting; this is only the default for a new account.
CALL_HISTORY_RETENTION_DAYS=30
```

- [ ] **Step 3: Write the coturn config**

Create `backend/coturn/turnserver.conf`:

```
listening-port=3478
tls-listening-port=443

fingerprint
use-auth-secret
static-auth-secret=REPLACED_AT_DEPLOY
realm=story

no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1

user-quota=12
total-quota=1200

denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
```

The `denied-peer-ip` lines matter: without them the relay can be pointed at your own private network and used to reach services that are not meant to face the internet.

- [ ] **Step 4: Write the compose file**

Create `backend/coturn/docker-compose.yml`:

```yaml
services:
  coturn:
    image: coturn/coturn:4.6
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./turnserver.conf:/etc/coturn/turnserver.conf:ro
    command:
      - -c
      - /etc/coturn/turnserver.conf
      - --static-auth-secret=${TURN_SHARED_SECRET}
      - --external-ip=${TURN_PUBLIC_IP}
```

`network_mode: host` is required. coturn allocates relay ports across a wide range, and mapping them one by one through Docker's NAT does not work.

- [ ] **Step 5: Open the ports**

In the EC2 security group, allow inbound `3478/udp`, `3478/tcp`, `443/tcp`, and `49152-65535/udp`. The last range is where coturn allocates relays.

- [ ] **Step 6: Verify the relay actually relays**

Run from a machine that is not the server:

```bash
docker run --rm instrumentisto/coturn turnutils_uclient \
  -u "$(python3 -c 'import time;print(int(time.time())+300)'):probe" \
  -W "$TURN_SHARED_SECRET" -y -v relay.example.org
```

Expected: `success` lines and a non-zero count of relayed packets. A failure here means the security group, not the code.

- [ ] **Step 7: Verify the API hands out working credentials**

```bash
curl -s -X POST https://<api-host>/v1/calls \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"conversation_id":"<an accepted conversation>"}' | python3 -m json.tool
```

Expected: `ice_servers` contains a `turns:` entry whose `username` starts with a unix timestamp roughly five minutes ahead.

- [ ] **Step 8: Document it**

Add a section to `docs/13-deploying-the-backend.md` covering: the container, the ports, where the secret lives, and the fact that the relay is in `eu-north-1` while users are not — cross-referencing `docs/17-voice-calling.md` §6.1.

- [ ] **Step 9: Commit**

```bash
git add backend/coturn backend/.env.example docs/13-deploying-the-backend.md
git commit -m "build(calls): run a TURN relay for the calls that cannot go direct"
```

---

## Self-Review

**Spec coverage.**

| Spec section | Task |
|---|---|
| §1 reuse of hub/bus/push | 3 |
| §2 accepted-conversation gate | 2 |
| §3 six signaling types | 3 |
| §4 lifecycle, 45s ring in Redis | 2, 3 |
| §5 media settings | client plan — no server work |
| §6 coturn, ephemeral credentials | 1, 9 |
| §6.1 `relayed` flag for measurement | 4 (field written; client sets it) |
| §7 two rows, indexes | 4 |
| §8 real deletes, retention, restamp, sweeper | 6, 7, 8 |
| §9 screens | client plan |
| §10 `media` as a list, `call.update` | 3, 4 |
| §11 exclusions | nothing built, by design |

**Gaps carried to the client plan, deliberately:** §5 media configuration, §9 all screens and Kotlin, and the client half of §6.1 (reporting `relayed` when a call ends). One backend gap is left open on purpose: `record_call` is written and tested in Task 4 but is not yet called from a request path, because the caller is `call.end` handling, which needs the client to report the outcome. Task 4 of the client plan closes it.

**Placeholder scan:** none. `REPLACED_AT_DEPLOY` in the coturn config is substituted by the compose `--static-auth-secret` flag at Step 4 and is not a plan placeholder.

**Type consistency:** `ice_servers(user_id, *, settings, now)` used identically in Tasks 1 and 2. `record_call` keyword arguments match between Task 4's definition and its test. `_expires_at(started_at, retention_days)` defined in Task 4, reused in Task 7. `SIGNAL_TYPES` defined in Task 3, imported in Task 3's socket dispatch. Constants `CALLS`, `RING_PREFIX`, `AUDIO`, `OUTBOUND`, `INBOUND` defined once in Task 2's `constants.py` and used unchanged thereafter.
