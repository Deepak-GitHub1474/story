from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.calls import constants as c
from app.logging import get_logger
from app.ports.push import PushMessage, PushPort

logger = get_logger("story.calls.ring")

PUSH_TOKENS = "push_tokens"


async def ring_push(
    *,
    callee_id: str,
    call_id: str,
    caller: dict[str, Any],
    mongo: AsyncIOMotorDatabase,
    push: PushPort,
) -> int:
    tokens = await mongo[PUSH_TOKENS].distinct("token", {"user_id": callee_id})
    if not tokens:
        return 0

    data = {
        "kind": "call",
        "call_id": call_id,
        "caller_name": str(caller.get("display_name") or caller.get("username") or ""),
        "caller_id": str(caller.get("user_id") or ""),
    }

    outcome = await push.send(
        [
            PushMessage(
                token=token,
                title="",
                body="",
                data=data,
                data_only=True,
            )
            for token in tokens
        ]
    )

    if outcome.stale:
        await mongo[PUSH_TOKENS].delete_many({"token": {"$in": list(outcome.stale)}})

    logger.info("call_ring_pushed", service="calls", count=outcome.sent)
    return outcome.sent


async def cancel_push(
    *, callee_id: str, call_id: str, mongo: AsyncIOMotorDatabase, push: PushPort
) -> int:
    tokens = await mongo[PUSH_TOKENS].distinct("token", {"user_id": callee_id})
    if not tokens:
        return 0

    data = {"kind": "call_cancelled", "call_id": call_id}
    outcome = await push.send(
        [
            PushMessage(token=token, title="", body="", data=data, data_only=True)
            for token in tokens
        ]
    )
    return outcome.sent


def pending_for(state: dict[str, Any], ice_servers: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "call_id": state["call_id"],
        "conversation_id": state["conversation_id"],
        "media": state.get("media") or [c.AUDIO],
        "sdp": state.get("offer_sdp"),
        "peer": state.get("caller_profile", {}),
        "ice_servers": ice_servers,
        "connected": state.get("connected_at") is not None,
    }
