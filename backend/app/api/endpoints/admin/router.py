from fastapi import APIRouter, Depends, status

from app.api.endpoints.admin import controllers
from app.api.endpoints.admin.models import BlockUserRequest, ResolveReportRequest
from app.core.deps import CurrentClaims, require_role
from app.db.mongo import MongoDatabase
from app.responses import ok_response

MODERATOR = require_role("moderator", "admin", "super_admin")
ADMIN = require_role("admin", "super_admin")

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/reports", dependencies=[Depends(MODERATOR)], status_code=status.HTTP_200_OK)
async def list_reports(mongo: MongoDatabase):
    data = await controllers.list_reports(mongo=mongo)
    return ok_response("Report queue.", data=data)


@router.post(
    "/reports/{report_id}/resolve",
    dependencies=[Depends(MODERATOR)],
    status_code=status.HTTP_200_OK,
)
async def resolve_report(
    report_id: str,
    body: ResolveReportRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.resolve_report(report_id, body, claims=claims, mongo=mongo)
    return ok_response("Report resolved.", data=data)


@router.get("/users/{username}", dependencies=[Depends(ADMIN)], status_code=status.HTTP_200_OK)
async def user_detail(username: str, mongo: MongoDatabase):
    data = await controllers.user_detail(username, mongo=mongo)
    return ok_response("Account loaded.", data=data)


@router.post(
    "/users/{username}/block",
    dependencies=[Depends(ADMIN)],
    status_code=status.HTTP_200_OK,
)
async def block_user(
    username: str,
    body: BlockUserRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.set_blocked(
        username, blocked=True, reason=body.reason, claims=claims, mongo=mongo
    )
    return ok_response("Account blocked.", data=data)


@router.post(
    "/users/{username}/unblock",
    dependencies=[Depends(ADMIN)],
    status_code=status.HTTP_200_OK,
)
async def unblock_user(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.set_blocked(
        username, blocked=False, reason=None, claims=claims, mongo=mongo
    )
    return ok_response("Account unblocked.", data=data)


@router.get("/stats", dependencies=[Depends(ADMIN)], status_code=status.HTTP_200_OK)
async def stats(mongo: MongoDatabase):
    data = await controllers.stats(mongo=mongo)
    return ok_response("Platform stats.", data=data)


@router.get("/audit", dependencies=[Depends(ADMIN)], status_code=status.HTTP_200_OK)
async def list_audit(mongo: MongoDatabase):
    data = await controllers.list_audit(mongo=mongo)
    return ok_response("Audit log.", data=data)
