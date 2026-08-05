from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.tickets.models import CreateTicketRequest
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.time import to_wire, utc_now

TICKETS = "support_tickets"
AUDIT = "audit_logs"

OPEN_STATES = ("draft", "submitted", "under_review", "needs_more_info", "reveal_ready")

REQUIRED_ROLE = {
    "passcode_release": "super_admin",
    "account_locked": "admin",
    "data_export": "admin",
    "account_deletion": "admin",
    "security_incident": "admin",
    "content_appeal": "moderator",
}


def serialize(doc: dict[str, Any]) -> dict[str, Any]:
    return {
        "ticket_id": doc["_id"],
        "type": doc["type"],
        "state": doc["state"],
        "reason": doc["reason"],
        "required_role": doc["required_role"],
        "resolution": doc.get("resolution"),
        "created_at": to_wire(doc.get("created_at")),
        "updated_at": to_wire(doc.get("updated_at")),
    }


async def create_ticket(
    body: CreateTicketRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    existing = await mongo[TICKETS].find_one(
        {"user_id": claims.user_id, "type": body.type, "state": {"$in": OPEN_STATES}},
        {"_id": 1},
    )
    if existing is not None:
        raise api_error(ErrorCode.TICKET_ALREADY_OPEN)

    now = utc_now()
    ticket = {
        "_id": new_id("tkt"),
        "user_id": claims.user_id,
        "type": body.type,
        "state": "submitted",
        "required_role": REQUIRED_ROLE[body.type],
        "reason": body.reason,
        "assignee_staff_id": None,
        "messages": [],
        "approval": None,
        "reveal": None,
        "resolution": None,
        "created_at": now,
        "updated_at": now,
        "closed_at": None,
    }
    await mongo[TICKETS].insert_one(ticket)
    return {"ticket": serialize(ticket)}


async def list_tickets(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[TICKETS]
        .find({"user_id": claims.user_id})
        .sort("_id", -1)
        .limit(50)
        .to_list(length=50)
    )
    return {"items": [serialize(doc) for doc in docs]}


async def security_activity(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[AUDIT]
        .find({"target.id": claims.user_id, "visible_to_target": True})
        .sort("_id", -1)
        .limit(50)
        .to_list(length=50)
    )
    return {
        "items": [
            {
                "action": doc["action"],
                "outcome": doc.get("outcome", "success"),
                "occurred_at": to_wire(doc.get("occurred_at")),
                "by_role": doc.get("actor", {}).get("role"),
            }
            for doc in docs
        ]
    }
