import hashlib
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.ids import new_id
from app.core.time import to_wire, utc_now

AUDIT = "audit_logs"


async def record(
    *,
    mongo: AsyncIOMotorDatabase,
    actor_id: str,
    actor_role: str,
    actor_username: str,
    action: str,
    target_kind: str,
    target_id: str,
    outcome: str = "success",
    details: dict[str, Any] | None = None,
) -> None:
    previous = await mongo[AUDIT].find_one({}, {"entry_hash": 1}, sort=[("_id", -1)])
    prev_hash = (previous or {}).get("entry_hash", "sha256:genesis")

    now = utc_now()
    entry = {
        "_id": new_id("aud"),
        "prev_hash": prev_hash,
        "occurred_at": now,
        "actor": {
            "user_id": actor_id,
            "role": actor_role,
            "username": actor_username,
        },
        "action": action,
        "target": {"kind": target_kind, "id": target_id},
        "outcome": outcome,
        "details": details or {},
        "visible_to_target": True,
    }

    payload = f"{prev_hash}|{entry['_id']}|{action}|{target_id}|{now.isoformat()}"
    entry["entry_hash"] = "sha256:" + hashlib.sha256(payload.encode()).hexdigest()

    await mongo[AUDIT].insert_one(entry)


def serialize(doc: dict[str, Any]) -> dict[str, Any]:
    return {
        "entry_id": doc["_id"],
        "action": doc["action"],
        "actor": doc.get("actor", {}),
        "target": doc.get("target", {}),
        "outcome": doc.get("outcome", "success"),
        "details": doc.get("details", {}),
        "occurred_at": to_wire(doc.get("occurred_at")),
    }
