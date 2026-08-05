from fastapi import APIRouter, status

from app.api.endpoints.users import controllers
from app.api.endpoints.users.models import (
    CancelDeleteRequest,
    DeactivateRequest,
    DeleteRequest,
    UpdateProfileRequest,
)
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/users", tags=["users"])


@router.patch("/me", status_code=status.HTTP_200_OK)
async def update_profile(body: UpdateProfileRequest, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.update_profile(body, claims=claims, mongo=mongo)
    return ok_response("Profile updated.", data=data)


@router.post("/me/avatar/regenerate", status_code=status.HTTP_200_OK)
async def regenerate_avatar(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.regenerate_avatar(claims=claims, mongo=mongo)
    return ok_response("New avatar ready.", data=data)


@router.get("/{username}", status_code=status.HTTP_200_OK)
async def public_profile(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.public_profile(username, claims=claims, mongo=mongo)
    return ok_response("Profile loaded.", data=data)


@router.post("/me/deactivate", status_code=status.HTTP_200_OK)
async def deactivate(
    body: DeactivateRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.deactivate(body, claims=claims, mongo=mongo, redis=redis)
    return ok_response("Account deactivated. Sign in any time to come back.", data=data)


@router.post("/me/delete", status_code=status.HTTP_200_OK)
async def request_deletion(
    body: DeleteRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.request_deletion(body, claims=claims, mongo=mongo, redis=redis)
    return ok_response("Deletion scheduled. You can cancel until then.", data=data)


@router.post("/me/delete/cancel", status_code=status.HTTP_200_OK)
async def cancel_deletion(body: CancelDeleteRequest, mongo: MongoDatabase):
    data = await controllers.cancel_deletion(body, mongo=mongo)
    return ok_response("Deletion cancelled.", data=data)
