from typing import Any

from redis.asyncio import Redis

from app.config import Settings
from app.core.crypto import constant_time_equals, hash_otp, new_otp
from app.core.errors import ErrorCode, api_error


async def issue(
    *, key: str, cooldown_key: str, redis: Redis, settings: Settings, enforce_cooldown: bool
) -> str:
    if enforce_cooldown and await redis.exists(cooldown_key):
        retry_after = await redis.ttl(cooldown_key)
        raise api_error(ErrorCode.OTP_COOLDOWN, extra={"retry_after_seconds": max(retry_after, 1)})

    otp = new_otp()
    await redis.hset(key, mapping={"hash": hash_otp(otp, secret=settings.OTP_HMAC_SECRET)})
    await redis.hsetnx(key, "attempts", 0)
    await redis.expire(key, settings.OTP_TTL_SECONDS)
    await redis.set(cooldown_key, "1", ex=settings.OTP_RESEND_COOLDOWN_SECONDS)
    return otp


async def verify(*, key: str, otp: str, redis: Redis, settings: Settings) -> None:
    record: dict[str, Any] = await redis.hgetall(key)
    if not record:
        raise api_error(ErrorCode.OTP_INVALID)

    attempts = int(record.get("attempts", 0))
    if attempts >= settings.OTP_FAIL_THRESHOLD:
        await redis.expire(key, settings.OTP_LOCKOUT_SECONDS)
        raise api_error(
            ErrorCode.OTP_LOCKED,
            extra={"retry_after_seconds": settings.OTP_LOCKOUT_SECONDS},
        )

    expected = record.get("hash", "")
    if not constant_time_equals(expected, hash_otp(otp, secret=settings.OTP_HMAC_SECRET)):
        remaining = await redis.hincrby(key, "attempts", 1)
        left = max(0, settings.OTP_FAIL_THRESHOLD - remaining)
        if left == 0:
            await redis.expire(key, settings.OTP_LOCKOUT_SECONDS)
            raise api_error(
                ErrorCode.OTP_LOCKED,
                extra={"retry_after_seconds": settings.OTP_LOCKOUT_SECONDS},
            )
        raise api_error(ErrorCode.OTP_INVALID, extra={"attempts_remaining": left})

    await redis.delete(key)
