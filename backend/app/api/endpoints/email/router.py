from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.api.endpoints.email import controllers
from app.api.endpoints.email.models import (
    AddEmailRequest,
    RemoveEmailRequest,
    ResendRequest,
    ResetCompleteRequest,
    ResetRequest,
    ResetVerifyRequest,
)
from app.core.deps import AppSettings, CurrentClaims, rate_limit_dep
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.ports.factory import build_mail
from app.ports.mail import MailPort
from app.responses import ok_response

router = APIRouter(tags=["email"])


def _mail(settings: AppSettings) -> MailPort:
    return build_mail(settings)


Mail = Annotated[MailPort, Depends(_mail)]


@router.post(
    "/users/me/email",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("email_add", 5, 3600))],
)
async def add_email(
    body: AddEmailRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
    mail: Mail,
):
    data = await controllers.add_email(
        body, claims=claims, mongo=mongo, redis=redis, settings=settings, mail=mail
    )
    return ok_response("We sent a code to that address.", data=data)


@router.post(
    "/users/me/email/resend",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("email_resend", 5, 3600))],
)
async def resend(
    body: ResendRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
    mail: Mail,
):
    data = await controllers.resend_otp(
        claims=claims, mongo=mongo, redis=redis, settings=settings, mail=mail
    )
    return ok_response("Another code is on its way.", data=data)


@router.post("/users/me/email/verify", status_code=status.HTTP_200_OK)
async def verify_email(
    body: dict,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.verify_email(
        str(body.get("otp", "")), claims=claims, mongo=mongo, redis=redis, settings=settings
    )
    return ok_response("Email verified.", data=data)


@router.delete("/users/me/email", status_code=status.HTTP_200_OK)
async def remove_email(
    body: RemoveEmailRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.remove_email(body, claims=claims, mongo=mongo, redis=redis)
    return ok_response("Email removed. Account recovery is no longer possible.", data=data)


@router.post(
    "/auth/password-reset/request",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("reset_request", 5, 3600))],
)
async def request_reset(
    body: ResetRequest,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
    mail: Mail,
):
    data = await controllers.request_reset(
        body.username, mongo=mongo, redis=redis, settings=settings, mail=mail
    )
    return ok_response(controllers.GENERIC_RESET_MESSAGE, data=data)


@router.post("/auth/password-reset/verify", status_code=status.HTTP_200_OK)
async def verify_reset(
    body: ResetVerifyRequest,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.verify_reset(body, mongo=mongo, redis=redis, settings=settings)
    return ok_response("Code accepted.", data=data)


@router.post("/auth/password-reset/complete", status_code=status.HTTP_200_OK)
async def complete_reset(
    body: ResetCompleteRequest,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.complete_reset(body, mongo=mongo, redis=redis, settings=settings)
    return ok_response("Password reset. Sign in with your new password.", data=data)
