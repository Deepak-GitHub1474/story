from fastapi import APIRouter, Depends, Request, status

from app.api.endpoints.auth import controllers
from app.api.endpoints.auth.models import (
    RefreshRequest,
    SigninWithDeviceRequest,
    SignupRequest,
    UsernameAvailableRequest,
)
from app.core.deps import AppSettings, ClientIpPrefix, CurrentClaims, rate_limit_dep
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/username-available",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("username_check", 10, 60))],
)
async def check_username(body: UsernameAvailableRequest, mongo: MongoDatabase):
    data = await controllers.username_available(body.username, mongo=mongo)
    message = "That username is available." if data["available"] else "That username is taken."
    return ok_response(message, data=data)


@router.post(
    "/signup",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("signup", 5, 3600))],
)
async def signup(
    body: SignupRequest,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.signup(body, mongo=mongo, redis=redis, settings=settings)
    return ok_response("Your account is ready.", data=data)


@router.post(
    "/signin",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("signin", 10, 300))],
)
async def signin(
    body: SigninWithDeviceRequest,
    ip_prefix: ClientIpPrefix,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.signin(
        body, ip_prefix=ip_prefix, mongo=mongo, redis=redis, settings=settings
    )
    return ok_response("Welcome back.", data=data)


@router.post(
    "/refresh",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("refresh", 60, 3600))],
)
async def refresh(
    body: RefreshRequest,
    mongo: MongoDatabase,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.refresh(
        body.refresh_token, mongo=mongo, redis=redis, settings=settings
    )
    return ok_response("Session refreshed.", data=data)


@router.post("/signout", status_code=status.HTTP_200_OK)
async def signout(
    request: Request,
    claims: CurrentClaims,
    redis: RedisClient,
    settings: AppSettings,
):
    data = await controllers.signout(
        claims=claims,
        redis=redis,
        settings=settings,
        refresh_token_value=request.cookies.get(settings.REFRESH_COOKIE_NAME),
    )
    return ok_response("Signed out.", data=data)


@router.post("/signout-all", status_code=status.HTTP_200_OK)
async def signout_all(claims: CurrentClaims, redis: RedisClient):
    data = await controllers.signout_all(claims=claims, redis=redis)
    return ok_response("Signed out everywhere.", data=data)


@router.get("/me", status_code=status.HTTP_200_OK)
async def me(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.me(claims=claims, mongo=mongo)
    return ok_response("Profile loaded.", data=data)
