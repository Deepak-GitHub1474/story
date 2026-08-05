from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.reports.models import CreateReportRequest
from app.core.errors import ErrorCode, api_error
from app.core.time import utc_now

REPORTS = "reports"

TARGETS = {
    "story": ("stories", "_id", "author_id"),
    "comment": ("comments", "_id", "author_id"),
    "user": ("users", "username_lower", "_id"),
}


async def _resolve(body: CreateReportRequest, mongo: AsyncIOMotorDatabase) -> tuple[str, str]:
    collection, field, owner_field = TARGETS[body.target_kind]
    key = body.target_id.lower() if body.target_kind == "user" else body.target_id

    document = await mongo[collection].find_one(
        {field: key, "deleted_at": None}, {owner_field: 1, "_id": 1}
    )
    if document is None:
        raise api_error(ErrorCode.REPORT_TARGET_NOT_FOUND)

    return document["_id"], document.get(owner_field, document["_id"])


async def create_report(
    body: CreateReportRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    target_id, owner_id = await _resolve(body, mongo)

    if owner_id == claims.user_id:
        raise api_error(ErrorCode.SELF_REPORT)

    now = utc_now()
    await mongo[REPORTS].update_one(
        {"_id": f"{claims.user_id}:{body.target_kind}:{target_id}"},
        {
            "$setOnInsert": {
                "reporter_id": claims.user_id,
                "target_kind": body.target_kind,
                "target_id": target_id,
                "target_owner_id": owner_id,
                "reason": body.reason,
                "note": body.note,
                "state": "open",
                "handled_by": None,
                "handled_at": None,
                "created_at": now,
            }
        },
        upsert=True,
    )

    return {"reported": True}
