from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.notifications.constants import NOTIFICATIONS, PREVIEW_LENGTH
from app.core.ids import new_id
from app.core.time import to_wire, utc_now


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
    }

    if collapse:
        await mongo[NOTIFICATIONS].update_one(
            {"user_id": user_id, "dedupe_key": document["dedupe_key"]},
            {"$set": {**document, "read_at": None}, "$setOnInsert": {"_id": new_id("not")}},
            upsert=True,
        )
        return

    await mongo[NOTIFICATIONS].insert_one({"_id": new_id("not"), **document})


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
