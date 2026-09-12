from fastapi import APIRouter, Depends, Query, status

from app.api.endpoints.calls import constants as c
from app.api.endpoints.calls import controllers
from app.api.endpoints.calls.models import (
    DeleteCallsRequest,
    RetentionRequest,
    StartCallRequest,
)
from app.core.deps import CurrentClaims, rate_limit_dep
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/calls", tags=["calls"])


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("call_start", 30, 3600))],
)
async def start_call(
    body: StartCallRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.start_call(body, claims=claims, mongo=mongo, redis=redis)
    return ok_response("Ringing.", data=data)


@router.get("", status_code=status.HTTP_200_OK)
async def list_calls(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = Query(default=c.HISTORY_DEFAULT_LIMIT, ge=1, le=c.HISTORY_MAX_LIMIT),
    cursor: str | None = Query(default=None),
):
    data = await controllers.list_calls(
        claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("Your calls.", data=data)


@router.put("/retention", status_code=status.HTTP_200_OK)
async def set_retention(
    body: RetentionRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.set_retention(body, claims=claims, mongo=mongo)
    return ok_response("Saved.", data=data)


@router.post("/delete", status_code=status.HTTP_200_OK)
async def delete_calls(
    body: DeleteCallsRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.delete_calls(body, claims=claims, mongo=mongo)
    return ok_response("Gone from your history.", data=data)


@router.get("/ringing", status_code=status.HTTP_200_OK)
async def ringing_for_me(claims: CurrentClaims, redis: RedisClient):
    data = await controllers.ringing_for_me(claims=claims, redis=redis)
    return ok_response("Someone is calling.", data=data)


@router.get("/{call_id}/pending", status_code=status.HTTP_200_OK)
async def pending_call(call_id: str, claims: CurrentClaims, redis: RedisClient):
    data = await controllers.pending_call(call_id, claims=claims, redis=redis)
    return ok_response("Someone is calling.", data=data)


@router.delete("/{call_id}", status_code=status.HTTP_200_OK)
async def delete_call(call_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.delete_call(call_id, claims=claims, mongo=mongo)
    return ok_response("Gone from your history.", data=data)
