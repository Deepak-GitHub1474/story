from datetime import UTC, datetime, timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from redis.asyncio import Redis

from app.adapters.turn import ice_servers
from app.api.endpoints.calls import constants as c
from app.api.endpoints.calls.models import (
    DeleteCallsRequest,
    RetentionRequest,
    StartCallRequest,
)
from app.api.endpoints.calls.signaling import save as save_ring
from app.config import get_settings
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.time import to_wire, utc_now


async def _conversation(
    conversation_id: str, user_id: str, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
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

    if conversation.get("state") != c.ACCEPTED:
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

    me = await mongo[c.USERS].find_one(
        {"_id": claims.user_id}, {"username": 1, "display_name": 1, "avatar_seed": 1}
    )

    call_id = new_id("cal")
    await save_ring(
        call_id,
        {
            "call_id": call_id,
            "caller": claims.user_id,
            "callee": peer_id,
            "conversation_id": body.conversation_id,
            "started_at": to_wire(utc_now()),
            "connected_at": None,
            "caller_profile": {
                "user_id": claims.user_id,
                "username": (me or {}).get("username", ""),
                "display_name": (me or {}).get("display_name")
                or (me or {}).get("username", ""),
                "avatar_seed": (me or {}).get("avatar_seed"),
            },
        },
        redis,
        settings.CALL_RING_TIMEOUT_SECONDS,
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


def _expires_at(started_at: datetime, retention_days: int) -> datetime | None:
    if retention_days <= 0:
        return None
    return started_at + timedelta(days=retention_days)


async def _retention_days(user_id: str, mongo: AsyncIOMotorDatabase) -> int:
    person = await mongo[c.USERS].find_one({"_id": user_id}, {"prefs": 1})
    prefs = (person or {}).get("prefs") or {}
    chosen = prefs.get("call_history_days")
    if isinstance(chosen, int):
        return chosen
    return get_settings().CALL_HISTORY_RETENTION_DAYS


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


def _wire(row: dict[str, Any], people: dict[str, dict[str, Any]]) -> dict[str, Any]:
    person = people.get(row["peer_id"], {})
    return {
        "call_id": row["call_id"],
        "peer_id": row["peer_id"],
        "peer": {
            "user_id": row["peer_id"],
            "username": person.get("username", ""),
            "display_name": person.get("display_name") or person.get("username", ""),
            "avatar_seed": person.get("avatar_seed"),
        },
        "conversation_id": row["conversation_id"],
        "direction": row["direction"],
        "outcome": row["outcome"],
        "media": row["media"],
        "relayed": row.get("relayed", False),
        "started_at": to_wire(row["started_at"]),
        "duration_seconds": row["duration_seconds"],
    }


def _encode_cursor(row: dict[str, Any]) -> str:
    return f"{row['started_at'].timestamp():.6f}|{row['_id']}"


def _decode_cursor(cursor: str) -> dict[str, Any] | None:
    moment, _, row_id = cursor.partition("|")
    if not row_id:
        return None
    try:
        started_at = datetime.fromtimestamp(float(moment), tz=UTC)
    except ValueError:
        return None
    return {
        "$or": [
            {"started_at": {"$lt": started_at}},
            {"started_at": started_at, "_id": {"$lt": row_id}},
        ]
    }


async def list_calls(
    *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    capped = max(1, min(limit, c.HISTORY_MAX_LIMIT))
    query: dict[str, Any] = {"owner_id": claims.user_id}
    if cursor:
        after = _decode_cursor(cursor)
        if after is not None:
            query.update(after)

    rows = (
        await mongo[c.CALLS]
        .find(query)
        .sort([("started_at", -1), ("_id", -1)])
        .limit(capped + 1)
        .to_list(length=capped + 1)
    )

    has_more = len(rows) > capped
    page = rows[:capped]

    peer_ids = {row["peer_id"] for row in page}
    found = await mongo[c.USERS].find(
        {"_id": {"$in": list(peer_ids)}},
        {"username": 1, "display_name": 1, "avatar_seed": 1},
    ).to_list(length=len(peer_ids) or 1)
    people = {person["_id"]: person for person in found}

    return {
        "items": [_wire(row, people) for row in page],
        "next_cursor": _encode_cursor(page[-1]) if has_more and page else None,
        "has_more": has_more,
    }


async def delete_call(call_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    result = await mongo[c.CALLS].delete_many(
        {"owner_id": claims.user_id, "call_id": call_id}
    )
    return {"deleted": result.deleted_count}


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


async def pending_call(call_id: str, *, claims, redis: Redis) -> dict[str, Any]:
    from app.api.endpoints.calls.ring import pending_for
    from app.api.endpoints.calls.signaling import load

    state = await load(call_id, redis)
    if state is None or state.get("callee") != claims.user_id:
        raise api_error(ErrorCode.CALL_NOT_FOUND)

    if not state.get("offer_sdp"):
        raise api_error(ErrorCode.CALL_NOT_FOUND)

    settings = get_settings()
    return pending_for(state, ice_servers(claims.user_id, settings=settings))
