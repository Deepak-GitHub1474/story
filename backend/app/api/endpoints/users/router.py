from fastapi import APIRouter, status

from app.api.endpoints.users import controllers
from app.api.endpoints.users.models import UpdateProfileRequest
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
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
    data = await controllers.public_profile(username, mongo=mongo)
    return ok_response("Profile loaded.", data=data)
