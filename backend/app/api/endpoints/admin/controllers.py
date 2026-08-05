from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.admin import audit
from app.api.endpoints.admin.models import ResolveReportRequest
from app.core.errors import ErrorCode, api_error
from app.core.time import to_wire, utc_now

USERS = "users"
REPORTS = "reports"
STORIES = "stories"
COMMENTS = "comments"

QUEUE_LIMIT = 50
AUDIT_LIMIT = 100

TARGET_COLLECTIONS = {"story": STORIES, "comment": COMMENTS, "user": USERS}


async def _target_preview(kind: str, target_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    collection = TARGET_COLLECTIONS.get(kind)
    if collection is None:
        return {"kind": kind, "id": target_id, "excerpt": "", "author": None}

    document = await mongo[collection].find_one(
        {"_id": target_id},
        {"excerpt": 1, "body": 1, "title": 1, "username": 1, "author_snapshot": 1},
    )
    if document is None:
        return {"kind": kind, "id": target_id, "excerpt": "(removed)", "author": None}

    if kind == "user":
        excerpt = f"@{document.get('username', '')}"
    else:
        excerpt = document.get("excerpt") or (document.get("body") or "")[:200]

    snapshot = document.get("author_snapshot") or {}
    return {
        "kind": kind,
        "id": target_id,
        "title": document.get("title"),
        "excerpt": excerpt or "(empty)",
        "author": snapshot.get("display_name"),
    }


async def list_reports(*, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[REPORTS]
        .find({"state": "open"})
        .sort("created_at", 1)
        .limit(QUEUE_LIMIT)
        .to_list(length=QUEUE_LIMIT)
    )

    items = []
    for doc in docs:
        items.append(
            {
                "report_id": doc["_id"],
                "reason": doc["reason"],
                "note": doc.get("note"),
                "state": doc["state"],
                "created_at": to_wire(doc.get("created_at")),
                "target": await _target_preview(doc["target_kind"], doc["target_id"], mongo),
            }
        )

    return {"items": items}


async def resolve_report(
    report_id: str, body: ResolveReportRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    report = await mongo[REPORTS].find_one({"_id": report_id, "state": "open"})
    if report is None:
        raise api_error(ErrorCode.REPORT_TARGET_NOT_FOUND)

    now = utc_now()
    await mongo[REPORTS].update_one(
        {"_id": report_id},
        {
            "$set": {
                "state": body.outcome,
                "handled_by": claims.user_id,
                "handled_at": now,
                "note": body.note or report.get("note"),
            }
        },
    )

    if body.outcome == "actioned":
        collection = TARGET_COLLECTIONS.get(report["target_kind"])
        if collection in (STORIES, COMMENTS):
            await mongo[collection].update_one(
                {"_id": report["target_id"]}, {"$set": {"deleted_at": now}}
            )

    staff = await mongo[USERS].find_one({"_id": claims.user_id}, {"username": 1, "role": 1})
    await audit.record(
        mongo=mongo,
        actor_id=claims.user_id,
        actor_role=staff["role"],
        actor_username=staff["username"],
        action=f"report.{body.outcome}",
        target_kind=report["target_kind"],
        target_id=report["target_id"],
        details={"reason": report["reason"]},
    )

    return {"resolved": True, "outcome": body.outcome}


async def user_detail(username: str, *, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[USERS].find_one(
        {"username_lower": username.lower()},
        {
            "_id": 1,
            "username": 1,
            "display_name": 1,
            "avatar_seed": 1,
            "role": 1,
            "status": 1,
            "blocked": 1,
            "blocked_reason": 1,
            "counts": 1,
            "created_at": 1,
            "last_login_at": 1,
        },
    )
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)

    return {
        "user": {
            "user_id": user["_id"],
            "username": user["username"],
            "display_name": user["display_name"],
            "avatar_seed": user.get("avatar_seed", ""),
            "role": user["role"],
            "status": user["status"],
            "blocked": user.get("blocked", False),
            "blocked_reason": user.get("blocked_reason"),
            "counts": user.get("counts", {}),
            "created_at": to_wire(user.get("created_at")),
            "last_login_at": to_wire(user.get("last_login_at")),
        }
    }


async def set_blocked(
    username: str,
    *,
    blocked: bool,
    reason: str | None,
    claims,
    mongo: AsyncIOMotorDatabase,
) -> dict[str, Any]:
    user = await mongo[USERS].find_one({"username_lower": username.lower()}, {"_id": 1})
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)

    now = utc_now()
    await mongo[USERS].update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "blocked": blocked,
                "blocked_reason": reason if blocked else None,
                "blocked_at": now if blocked else None,
                "updated_at": now,
            }
        },
    )

    staff = await mongo[USERS].find_one({"_id": claims.user_id}, {"username": 1, "role": 1})
    await audit.record(
        mongo=mongo,
        actor_id=claims.user_id,
        actor_role=staff["role"],
        actor_username=staff["username"],
        action="account.blocked" if blocked else "account.unblocked",
        target_kind="user",
        target_id=user["_id"],
        details={"reason": reason} if reason else {},
    )

    return {"blocked": blocked, "username": username}


async def stats(*, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    return {
        "users": await mongo[USERS].count_documents({"deleted_at": None}),
        "blocked_users": await mongo[USERS].count_documents({"blocked": True}),
        "stories": await mongo[STORIES].count_documents(
            {"visibility": "public", "deleted_at": None}
        ),
        "comments": await mongo[COMMENTS].count_documents({"deleted_at": None}),
        "open_reports": await mongo[REPORTS].count_documents({"state": "open"}),
        "communities": await mongo["communities"].count_documents({"status": "active"}),
    }


async def list_audit(*, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[audit.AUDIT]
        .find({})
        .sort("_id", -1)
        .limit(AUDIT_LIMIT)
        .to_list(length=AUDIT_LIMIT)
    )
    return {"items": [audit.serialize(doc) for doc in docs]}
