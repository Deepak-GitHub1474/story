import json
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from redis.asyncio import Redis

from app.adapters.turn import ice_servers
from app.api.endpoints.calls import constants as c
from app.config import get_settings
from app.core.time import utc_now
from app.logging import get_logger
from app.realtime import bus

logger = get_logger("story.calls.signaling")

SIGNAL_TYPES = frozenset(
    {"call.offer", "call.answer", "call.ice", "call.update", "call.end"}
)

RELAYED_FIELDS = ("sdp", "candidate", "media", "reason", "muted", "conversation_id")


def ring_key(call_id: str) -> str:
    return f"{c.RING_PREFIX}{call_id}"


def ringing_for_key(user_id: str) -> str:
    return f"{c.RINGING_FOR_PREFIX}{user_id}"


async def load(call_id: str, redis: Redis) -> dict[str, Any] | None:
    raw = await redis.get(ring_key(call_id))
    if raw is None:
        return None
    try:
        return json.loads(raw.decode() if isinstance(raw, bytes) else str(raw))
    except ValueError:
        return None


async def save(call_id: str, state: dict[str, Any], redis: Redis, ttl: int) -> None:
    await redis.set(ring_key(call_id), json.dumps(state), ex=ttl)


def _outcome(state: dict[str, Any], reason: str, ended_by: str) -> str:
    if state.get("connected_at"):
        return c.ANSWERED
    if reason == "declined":
        return c.DECLINED
    if reason == "busy":
        return c.BUSY
    if reason in ("timeout", "hangup") and ended_by == state["caller"]:
        return c.MISSED
    if reason == "timeout":
        return c.MISSED
    return c.FAILED


async def _record(
    state: dict[str, Any], reason: str, ended_by: str, mongo: AsyncIOMotorDatabase
) -> None:
    from app.api.endpoints.calls.controllers import record_call
    from app.core.time import from_wire

    started_at = from_wire(state["started_at"])
    connected_raw = state.get("connected_at")
    connected_at = from_wire(connected_raw) if connected_raw else None

    await record_call(
        call_id=state["call_id"],
        caller_id=state["caller"],
        callee_id=state["callee"],
        conversation_id=state["conversation_id"],
        outcome=_outcome(state, reason, ended_by),
        started_at=started_at,
        connected_at=connected_at,
        ended_at=utc_now(),
        mongo=mongo,
    )


async def handle(
    event: dict[str, Any],
    *,
    user_id: str,
    redis: Redis,
    mongo: AsyncIOMotorDatabase | None = None,
) -> None:
    kind = event.get("type")
    call_id = event.get("call_id")
    if kind not in SIGNAL_TYPES or not isinstance(call_id, str):
        return

    state = await load(call_id, redis)
    if state is None:
        return

    caller = state["caller"]
    callee = state["callee"]
    if user_id not in (caller, callee):
        return

    peer = callee if user_id == caller else caller

    payload: dict[str, Any] = {"type": kind, "call_id": call_id, "from": user_id}
    for field in RELAYED_FIELDS:
        if field in event:
            payload[field] = event[field]

    settings = get_settings()

    if kind == "call.offer":
        state["offer_sdp"] = event.get("sdp")
        state["media"] = event.get("media") or [c.AUDIO]
        await save(call_id, state, redis, settings.CALL_RING_TIMEOUT_SECONDS)

        payload["conversation_id"] = state["conversation_id"]
        payload["ice_servers"] = ice_servers(peer, settings=settings)
        payload["ring_timeout_seconds"] = settings.CALL_RING_TIMEOUT_SECONDS
        payload["caller"] = state.get("caller_profile", {})

    if kind == "call.answer" and not state.get("connected_at"):
        state["connected_at"] = utc_now().isoformat().replace("+00:00", "Z")
        await save(call_id, state, redis, settings.CALL_RING_TIMEOUT_SECONDS * 60)

    logger.info(
        "call_signal",
        service="calls",
        code=kind,
        error=f"{user_id[-6:]}->{peer[-6:]} {call_id[-6:]} {event.get('reason') or ''}",
    )
    await bus.publish(redis, [peer], payload)

    if kind == "call.offer" and mongo is not None:
        from app.api.endpoints.calls.ring import ring_push
        from app.ports.factory import build_push

        try:
            await ring_push(
                callee_id=callee,
                call_id=call_id,
                caller=state.get("caller_profile", {}),
                mongo=mongo,
                push=build_push(settings),
            )
        except Exception:
            logger.error("call_ring_push_failed", code="call_ring_push_failed")

    if kind == "call.end":
        await redis.delete(ringing_for_key(callee))
        if mongo is not None:
            await _record(
                state, event.get("reason") or "hangup", user_id, mongo
            )
        await redis.delete(ring_key(call_id))
