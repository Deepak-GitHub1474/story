from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.notifications import constants as c
from app.api.endpoints.notifications.service import serialize
from app.core.errors import ErrorCode, api_error
from app.core.time import utc_now


async def list_notifications(
    *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None, unread_only: bool
) -> dict[str, Any]:
    limit = max(1, min(limit, c.MAX_LIMIT))
    query: dict[str, Any] = {"user_id": claims.user_id}
    if unread_only:
        query["read_at"] = None
    if cursor:
        query["_id"] = {"$lt": cursor}

    docs = (
        await mongo[c.NOTIFICATIONS]
        .find(query)
        .sort("_id", -1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )
    has_more = len(docs) > limit
    page = docs[:limit]

    return {
        "items": [serialize(doc) for doc in page],
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


async def unread_count(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    count = await mongo[c.NOTIFICATIONS].count_documents(
        {"user_id": claims.user_id, "read_at": None}
    )
    return {"unread": count}


async def mark_read(notification_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    result = await mongo[c.NOTIFICATIONS].update_one(
        {"_id": notification_id, "user_id": claims.user_id, "read_at": None},
        {"$set": {"read_at": utc_now()}},
    )
    if result.matched_count == 0:
        existing = await mongo[c.NOTIFICATIONS].find_one(
            {"_id": notification_id, "user_id": claims.user_id}, {"_id": 1}
        )
        if existing is None:
            raise api_error(ErrorCode.NOTIFICATION_NOT_FOUND)
    return {"read": True, "notification_id": notification_id}


async def mark_all_read(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    result = await mongo[c.NOTIFICATIONS].update_many(
        {"user_id": claims.user_id, "read_at": None}, {"$set": {"read_at": utc_now()}}
    )
    return {"read": True, "count": result.modified_count}
