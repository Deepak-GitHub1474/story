import asyncio
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ReturnDocument
from redis.asyncio import Redis

from app.api.endpoints.notifications.constants import NOTIFICATIONS, PREVIEW_LENGTH
from app.config import get_settings
from app.core.ids import new_id
from app.core.time import to_wire, utc_now
from app.logging import get_logger
from app.ports.factory import build_push
from app.realtime import bus
from app.workers.push import deliver_now

logger = get_logger("story.notifications")

_IN_FLIGHT: set[asyncio.Task] = set()


def preview(text: str) -> str:
    flattened = " ".join(text.split())
    if len(flattened) <= PREVIEW_LENGTH:
        return flattened
    return flattened[: PREVIEW_LENGTH - 1].rstrip() + "…"


def dedupe_key(kind: str, actor_id: str, target_id: str) -> str:
    return f"{kind}:{actor_id}:{target_id}"


async def notify(
    *,
    mongo: AsyncIOMotorDatabase,
    user_id: str,
    actor_id: str,
    actor_snapshot: dict[str, Any],
    kind: str,
    target_kind: str,
    target_id: str,
    body: str,
    collapse: bool = False,
    redis: Redis | None = None,
) -> None:
    if user_id == actor_id:
        return

    recipient = await mongo["users"].find_one({"_id": user_id}, {"prefs": 1})
    if recipient and recipient.get("prefs", {}).get("notify_in_app") is False:
        return

    now = utc_now()
    document = {
        "user_id": user_id,
        "actor_id": actor_id,
        "actor_snapshot": actor_snapshot,
        "kind": kind,
        "target": {"kind": target_kind, "id": target_id},
        "body": body,
        "dedupe_key": dedupe_key(kind, actor_id, target_id),
        "read_at": None,
        "created_at": now,
        "push_after": now,
    }

    if collapse:
        merged = await mongo[NOTIFICATIONS].find_one_and_update(
            {"user_id": user_id, "dedupe_key": document["dedupe_key"]},
            {"$set": {**document, "read_at": None}, "$setOnInsert": {"_id": new_id("not")}},
            upsert=True,
            return_document=ReturnDocument.AFTER,
            projection={"_id": 1},
        )
        await announce(redis, user_id, kind)
        push_soon(mongo, merged["_id"], redis)
        return

    notification_id = new_id("not")
    await mongo[NOTIFICATIONS].insert_one(
        {
            "_id": notification_id,
            **document,
            "dedupe_key": f"{document['dedupe_key']}:{notification_id}",
        }
    )
    await announce(redis, user_id, kind)
    push_soon(mongo, notification_id, redis)


def push_soon(
    mongo: AsyncIOMotorDatabase, notification_id: str, redis: Redis | None
) -> None:
    settings = get_settings()
    if settings.PUSH_PROVIDER == "none":
        return

    try:
        push = build_push(settings)
    except ValueError as exc:
        logger.error("push_misconfigured", error=str(exc))
        return

    task = asyncio.create_task(
        deliver_now(
            notification_id,
            mongo=mongo,
            push=push,
            redis=redis,
            lease_seconds=settings.PUSH_LEASE_SECONDS,
            max_tries=settings.PUSH_MAX_TRIES,
        )
    )
    _IN_FLIGHT.add(task)
    task.add_done_callback(_IN_FLIGHT.discard)


async def announce(redis: Redis | None, user_id: str, kind: str) -> None:
    if redis is None:
        return
    await bus.publish(redis, [user_id], {"type": "notification", "kind": kind})


async def withdraw(
    *, mongo: AsyncIOMotorDatabase, user_id: str, kind: str, actor_id: str, target_id: str
) -> None:
    await mongo[NOTIFICATIONS].delete_many(
        {"user_id": user_id, "dedupe_key": dedupe_key(kind, actor_id, target_id)}
    )


def serialize(doc: dict[str, Any]) -> dict[str, Any]:
    snapshot = doc.get("actor_snapshot") or {}
    return {
        "notification_id": doc["_id"],
        "kind": doc["kind"],
        "actor": {
            "user_id": doc.get("actor_id"),
            "display_name": snapshot.get("display_name", "Someone"),
            "avatar_seed": snapshot.get("avatar_seed", ""),
            "username": snapshot.get("username"),
        },
        "target": doc.get("target"),
        "body": doc.get("body", ""),
        "is_read": doc.get("read_at") is not None,
        "created_at": to_wire(doc.get("created_at")),
    }
