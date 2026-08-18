from fastapi import APIRouter, status

from app.api.endpoints.notifications import constants as c
from app.api.endpoints.notifications import controllers
from app.api.endpoints.notifications.models import (
    ForgetPushTokenRequest,
    RegisterPushTokenRequest,
)
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", status_code=status.HTTP_200_OK)
async def list_notifications(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = c.DEFAULT_LIMIT,
    cursor: str | None = None,
    unread_only: bool = False,
):
    data = await controllers.list_notifications(
        claims=claims, mongo=mongo, limit=limit, cursor=cursor, unread_only=unread_only
    )
    return ok_response("Notifications loaded.", data=data)


@router.get("/unread-count", status_code=status.HTTP_200_OK)
async def unread_count(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.unread_count(claims=claims, mongo=mongo)
    return ok_response("Unread count.", data=data)


@router.post("/push-tokens", status_code=status.HTTP_201_CREATED)
async def register_push_token(
    body: RegisterPushTokenRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.register_push_token(body, claims=claims, mongo=mongo)
    return ok_response("This device will receive notifications.", data=data)


@router.delete("/push-tokens", status_code=status.HTTP_200_OK)
async def forget_push_token(
    body: ForgetPushTokenRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.forget_push_token(body, claims=claims, mongo=mongo)
    return ok_response("This device will stop receiving notifications.", data=data)


@router.post("/{notification_id}/read", status_code=status.HTTP_200_OK)
async def mark_read(notification_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.mark_read(notification_id, claims=claims, mongo=mongo)
    return ok_response("Marked as read.", data=data)


@router.delete("/{notification_id}", status_code=status.HTTP_200_OK)
async def remove(notification_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.remove(notification_id, claims=claims, mongo=mongo)
    return ok_response("Cleared.", data=data)


@router.post("/read-all", status_code=status.HTTP_200_OK)
async def mark_all_read(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.mark_all_read(claims=claims, mongo=mongo)
    return ok_response("All caught up.", data=data)
