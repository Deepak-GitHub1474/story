from datetime import timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ReturnDocument
from redis.asyncio import Redis

from app.api.endpoints.notifications.constants import NOTIFICATIONS, PUSH_TOKENS
from app.core.time import utc_now
from app.db import keys
from app.logging import get_logger
from app.ports.push import PushMessage, PushPort

logger = get_logger("story.workers.push")

USERS = "users"
SWEEP_BATCH = 200


def compose(doc: dict[str, Any]) -> tuple[str, str]:
    snapshot = doc.get("actor_snapshot") or {}
    return snapshot.get("display_name") or "Story", doc.get("body") or ""


def payload(doc: dict[str, Any]) -> dict[str, str]:
    target = doc.get("target") or {}
    snapshot = doc.get("actor_snapshot") or {}
    return {
        "notification_id": str(doc["_id"]),
        "kind": str(doc.get("kind") or ""),
        "target_kind": str(target.get("kind") or ""),
        "target_id": str(target.get("id") or ""),
        "username": str(snapshot.get("username") or ""),
        "thread": str(doc.get("dedupe_key") or doc["_id"]),
    }


async def _is_online(redis: Redis | None, user_id: str) -> bool:
    if redis is None:
        return False
    return await redis.get(keys.presence(user_id)) is not None


async def _wants_push(mongo: AsyncIOMotorDatabase, user_id: str) -> bool:
    user = await mongo[USERS].find_one({"_id": user_id}, {"prefs": 1})
    return bool((user or {}).get("prefs", {}).get("notify_push"))


async def _settle(mongo: AsyncIOMotorDatabase, notification_id: str, *, sent: bool) -> None:
    update: dict[str, Any] = {"$unset": {"push_after": ""}}
    if sent:
        update["$set"] = {"pushed_at": utc_now()}
    await mongo[NOTIFICATIONS].update_one({"_id": notification_id}, update)


async def claim(
    mongo: AsyncIOMotorDatabase, notification_id: str, *, now, lease_seconds: int
) -> dict[str, Any] | None:
    return await mongo[NOTIFICATIONS].find_one_and_update(
        {"_id": notification_id, "push_after": {"$lte": now}},
        {
            "$set": {"push_after": now + timedelta(seconds=lease_seconds)},
            "$inc": {"push_tries": 1},
        },
        return_document=ReturnDocument.AFTER,
    )


async def deliver(
    doc: dict[str, Any],
    *,
    mongo: AsyncIOMotorDatabase,
    push: PushPort,
    redis: Redis | None,
    max_tries: int,
) -> int:
    notification_id = doc["_id"]
    user_id = doc["user_id"]

    if doc.get("push_tries", 1) > max_tries:
        logger.warning("push_gave_up", code="push_gave_up", error=str(notification_id))
        await _settle(mongo, notification_id, sent=False)
        return 0

    if await _is_online(redis, user_id):
        await _settle(mongo, notification_id, sent=False)
        return 0

    if not await _wants_push(mongo, user_id):
        await _settle(mongo, notification_id, sent=False)
        return 0

    tokens = await mongo[PUSH_TOKENS].distinct("token", {"user_id": user_id})
    if not tokens:
        await _settle(mongo, notification_id, sent=False)
        return 0

    title, body = compose(doc)
    data = payload(doc)
    outcome = await push.send(
        [PushMessage(token=token, title=title, body=body, data=data) for token in tokens]
    )

    if outcome.stale:
        await mongo[PUSH_TOKENS].delete_many({"token": {"$in": list(outcome.stale)}})

    if outcome.retry and not outcome.delivered:
        return 0

    await _settle(mongo, notification_id, sent=True)
    return outcome.sent


async def deliver_now(
    notification_id: str,
    *,
    mongo: AsyncIOMotorDatabase,
    push: PushPort,
    redis: Redis | None,
    lease_seconds: int,
    max_tries: int,
) -> int:
    if not push.is_available:
        return 0

    doc = await claim(mongo, notification_id, now=utc_now(), lease_seconds=lease_seconds)
    if doc is None:
        return 0

    try:
        return await deliver(doc, mongo=mongo, push=push, redis=redis, max_tries=max_tries)
    except Exception as exc:
        logger.error("push_deliver_failed", error=f"{type(exc).__name__}: {exc}")
        return 0


async def sweep_due(
    *,
    mongo: AsyncIOMotorDatabase,
    push: PushPort,
    redis: Redis | None,
    lease_seconds: int,
    max_tries: int,
) -> int:
    if not push.is_available:
        return 0

    due = (
        await mongo[NOTIFICATIONS]
        .find({"push_after": {"$lte": utc_now()}}, {"_id": 1})
        .sort("push_after", 1)
        .limit(SWEEP_BATCH)
        .to_list(length=SWEEP_BATCH)
    )

    sent = 0
    for row in due:
        sent += await deliver_now(
            row["_id"],
            mongo=mongo,
            push=push,
            redis=redis,
            lease_seconds=lease_seconds,
            max_tries=max_tries,
        )
    return sent
