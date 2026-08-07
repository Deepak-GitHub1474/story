from typing import Annotated

from fastapi import Depends, Request

from app.config import Settings, get_settings
from app.core.errors import ErrorCode, api_error
from app.core.tokens import AccessClaims, TokenError, decode_access_token
from app.db.keys import access_denylist, rate_limit, session_epoch
from app.db.redis import RedisClient
from app.ports.ai import AIPort
from app.ports.factory import build_ai, build_mail
from app.ports.mail import MailPort

AppSettings = Annotated[Settings, Depends(get_settings)]


def get_ai(settings: AppSettings) -> AIPort:
    return build_ai(settings)


AI = Annotated[AIPort, Depends(get_ai)]


def get_mail(settings: AppSettings) -> MailPort:
    return build_mail(settings)


Mail = Annotated[MailPort, Depends(get_mail)]


def _bearer_token(request: Request, settings: Settings) -> str | None:
    cookie = request.cookies.get(settings.ACCESS_COOKIE_NAME)
    if cookie:
        return cookie
    header = request.headers.get("authorization", "")
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    return None


async def get_current_claims(
    request: Request,
    settings: AppSettings,
    redis: RedisClient,
) -> AccessClaims:
    token = _bearer_token(request, settings)
    if not token:
        raise api_error(ErrorCode.SESSION_REQUIRED)

    try:
        claims = decode_access_token(token, secret=settings.JWT_SECRET)
    except TokenError as exc:
        code = ErrorCode.TOKEN_EXPIRED if "expired" in str(exc).lower() else ErrorCode.TOKEN_INVALID
        raise api_error(code) from exc

    if await redis.exists(access_denylist(claims.jti)):
        raise api_error(ErrorCode.TOKEN_REVOKED)

    epoch = await redis.get(session_epoch(claims.user_id))
    if epoch is not None and claims.issued_at_ms < int(epoch):
        raise api_error(ErrorCode.TOKEN_REVOKED)

    request.state.user_id = claims.user_id
    return claims


CurrentClaims = Annotated[AccessClaims, Depends(get_current_claims)]


def require_role(*roles: str):

    async def dependency(claims: CurrentClaims) -> AccessClaims:
        if claims.role not in roles:
            raise api_error(ErrorCode.ROLE_REQUIRED, extra={"required_role": sorted(roles)[0]})
        return claims

    return dependency


def client_ip_prefix(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "")
    raw = (
        forwarded.split(",")[0].strip()
        if forwarded
        else (request.client.host if request.client else "0.0.0.0")
    )
    if ":" in raw:
        return ":".join(raw.split(":")[:3]) + "::"
    parts = raw.split(".")
    return ".".join(parts[:3] + ["0"]) if len(parts) == 4 else "0.0.0.0"


ClientIpPrefix = Annotated[str, Depends(client_ip_prefix)]


def rate_limit_dep(scope: str, limit: int, window_seconds: int):

    async def dependency(request: Request, redis: RedisClient, settings: AppSettings) -> None:
        if not settings.RATE_LIMIT_ENABLED:
            return
        identity = getattr(request.state, "user_id", None) or client_ip_prefix(request)
        key = rate_limit(scope, identity)
        count = await redis.incr(key)
        if count == 1:
            await redis.expire(key, window_seconds)
        if count > limit:
            retry_after = await redis.ttl(key)
            raise api_error(
                ErrorCode.RATE_LIMITED,
                extra={"retry_after_seconds": max(retry_after, 1)},
            )

    return dependency
