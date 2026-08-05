from fastapi import APIRouter, status

from app.api.endpoints.totp import controllers
from app.api.endpoints.totp.models import ConfirmTotpRequest, DisableTotpRequest
from app.core.deps import AppSettings, CurrentClaims
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/auth/totp", tags=["totp"])


@router.post("/setup", status_code=status.HTTP_200_OK)
async def start_setup(claims: CurrentClaims, mongo: MongoDatabase, settings: AppSettings):
    data = await controllers.start_setup(claims=claims, mongo=mongo, settings=settings)
    return ok_response(
        "Add this key to your authenticator app, then confirm with the code it shows.",
        data=data,
    )


@router.post("/confirm", status_code=status.HTTP_200_OK)
async def confirm_setup(
    body: ConfirmTotpRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    settings: AppSettings,
):
    data = await controllers.confirm_setup(
        body, claims=claims, mongo=mongo, settings=settings
    )
    return ok_response(
        "Authenticator active. Save these backup codes now — they are shown once.",
        data=data,
    )


@router.get("", status_code=status.HTTP_200_OK)
async def read_status(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.read_status(claims=claims, mongo=mongo)
    return ok_response("Authenticator status.", data=data)


@router.post("/disable", status_code=status.HTTP_200_OK)
async def disable(
    body: DisableTotpRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.disable(
        body, claims=claims, mongo=mongo, redis=redis, settings=settings
    )
    return ok_response("Authenticator removed.", data=data)
