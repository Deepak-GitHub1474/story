from fastapi import APIRouter, Depends, status

from app.api.endpoints.admin import audit
from app.api.endpoints.tickets.controllers import TICKETS
from app.api.endpoints.tickets.models import ReleaseEscrowRequest
from app.core.deps import CurrentClaims, require_role
from app.core.errors import ErrorCode, api_error
from app.core.time import to_wire, utc_now
from app.db.mongo import MongoDatabase
from app.responses import ok_response

SUPER_ADMIN = require_role("super_admin")

router = APIRouter(prefix="/admin/vault", tags=["admin-vault"])

USERS = "users"
PASSCODES = "user_passcodes"

METADATA_ONLY = {
    "_id": 1,
    "label": 1,
    "scope": 1,
    "created_at": 1,
    "last_used_at": 1,
    "failed_attempts": 1,
    "locked_until": 1,
}


async def _owner(username: str, mongo):
    user = await mongo[USERS].find_one(
        {"username_lower": username.lower()}, {"_id": 1, "username": 1}
    )
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)
    return user


async def _staff(claims, mongo):
    return await mongo[USERS].find_one({"_id": claims.user_id}, {"username": 1, "role": 1})


@router.get(
    "/{username}/passcodes",
    dependencies=[Depends(SUPER_ADMIN)],
    status_code=status.HTTP_200_OK,
)
async def list_passcodes(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    owner = await _owner(username, mongo)

    docs = await mongo[PASSCODES].find({"user_id": owner["_id"]}, METADATA_ONLY).to_list(length=100)

    staff = await _staff(claims, mongo)
    await audit.record(
        mongo=mongo,
        actor_id=claims.user_id,
        actor_role=staff["role"],
        actor_username=staff["username"],
        action="vault.passcodes_listed",
        target_kind="user",
        target_id=owner["_id"],
        details={"count": len(docs)},
    )

    return ok_response(
        "Passcode names only. No value, no hash, no key material.",
        data={
            "items": [
                {
                    "passcode_id": doc["_id"],
                    "label": doc["label"],
                    "scope": doc.get("scope", "vault"),
                    "failed_attempts": doc.get("failed_attempts", 0),
                    "created_at": to_wire(doc.get("created_at")),
                    "last_used_at": to_wire(doc.get("last_used_at")),
                }
                for doc in docs
            ]
        },
    )


@router.post(
    "/{username}/release",
    dependencies=[Depends(SUPER_ADMIN)],
    status_code=status.HTTP_200_OK,
)
async def release_escrow(
    username: str,
    body: ReleaseEscrowRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    owner = await _owner(username, mongo)

    ticket = await mongo[TICKETS].find_one(
        {
            "_id": body.ticket_id,
            "user_id": owner["_id"],
            "type": "passcode_release",
            "state": {"$in": ["submitted", "under_review", "needs_more_info"]},
        }
    )
    if ticket is None:
        raise api_error(ErrorCode.TICKET_NOT_FOUND)

    now = utc_now()
    await mongo[TICKETS].update_one(
        {"_id": body.ticket_id},
        {
            "$set": {
                "state": "reveal_ready",
                "approval": {
                    "approved_by": claims.user_id,
                    "approved_at": now,
                    "justification": body.justification,
                },
                "updated_at": now,
            }
        },
    )

    staff = await _staff(claims, mongo)
    await audit.record(
        mongo=mongo,
        actor_id=claims.user_id,
        actor_role=staff["role"],
        actor_username=staff["username"],
        action="passcode_release.approved",
        target_kind="user",
        target_id=owner["_id"],
        details={"ticket_id": body.ticket_id, "justification": body.justification},
    )

    return ok_response(
        "Released to the account owner. The material never passes through staff.",
        data={"released": True, "ticket_id": body.ticket_id},
    )
