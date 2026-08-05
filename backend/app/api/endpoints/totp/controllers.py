from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.config import Settings
from app.core.errors import ErrorCode, api_error
from app.core.time import to_wire, utc_now
from app.core.totp import (
    STEP_SECONDS,
    hash_backup_code,
    new_backup_codes,
    new_secret,
    provisioning_uri,
    verify,
)
from app.db import keys

USERS = "users"
STAFF_ROLES = ("moderator", "admin", "super_admin")
REPLAY_TTL_SECONDS = STEP_SECONDS * 3


async def _staff_or_refuse(claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[USERS].find_one(
        {"_id": claims.user_id}, {"username": 1, "role": 1, "totp": 1}
    )
    if user is None or user.get("role") not in STAFF_ROLES:
        raise api_error(ErrorCode.ROLE_REQUIRED)
    return user


async def start_setup(*, claims, mongo: AsyncIOMotorDatabase, settings: Settings) -> dict[str, Any]:
    user = await _staff_or_refuse(claims, mongo)
    if (user.get("totp") or {}).get("enabled_at"):
        raise api_error(ErrorCode.TOTP_ALREADY_ENABLED)

    secret = new_secret()
    await mongo[USERS].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "totp": {
                    "secret": secret,
                    "enabled_at": None,
                    "backup_hashes": [],
                    "created_at": utc_now(),
                }
            }
        },
    )

    return {
        "secret": secret,
        "uri": provisioning_uri(
            secret, username=user["username"], issuer=settings.TOTP_ISSUER
        ),
    }


async def confirm_setup(
    body, *, claims, mongo: AsyncIOMotorDatabase, settings: Settings
) -> dict[str, Any]:
    user = await _staff_or_refuse(claims, mongo)
    totp = user.get("totp") or {}
    if not totp.get("secret"):
        raise api_error(ErrorCode.TOTP_REQUIRED)
    if totp.get("enabled_at"):
        raise api_error(ErrorCode.TOTP_ALREADY_ENABLED)
    if not verify(totp["secret"], body.code):
        raise api_error(ErrorCode.TOTP_INVALID, field="code")

    codes = new_backup_codes()
    await mongo[USERS].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "totp.enabled_at": utc_now(),
                "totp.backup_hashes": [
                    hash_backup_code(code, secret=settings.OTP_HMAC_SECRET)
                    for code in codes
                ],
            }
        },
    )

    return {"enabled": True, "backup_codes": codes}


async def read_status(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await _staff_or_refuse(claims, mongo)
    totp = user.get("totp") or {}
    return {
        "enabled": bool(totp.get("enabled_at")),
        "started": bool(totp.get("secret")),
        "enabled_at": to_wire(totp.get("enabled_at")),
        "backups_left": len(totp.get("backup_hashes", [])),
    }


async def disable(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    await _staff_or_refuse(claims, mongo)
    await mongo[USERS].update_one({"_id": claims.user_id}, {"$unset": {"totp": ""}})
    return {"enabled": False}


async def require_code(
    code: str | None, *, claims, mongo: AsyncIOMotorDatabase, redis, settings: Settings
) -> None:
    user = await mongo[USERS].find_one({"_id": claims.user_id}, {"totp": 1})
    totp = (user or {}).get("totp") or {}
    if not totp.get("enabled_at"):
        raise api_error(ErrorCode.TOTP_REQUIRED)

    if not code:
        raise api_error(ErrorCode.TOTP_INVALID, field="totp_code")

    replay_key = keys.totp_used(claims.user_id, code)
    if await redis.get(replay_key):
        raise api_error(ErrorCode.TOTP_REUSED, field="totp_code")

    if verify(totp["secret"], code):
        await redis.set(replay_key, "1", ex=REPLAY_TTL_SECONDS)
        return

    candidate = hash_backup_code(code, secret=settings.OTP_HMAC_SECRET)
    if candidate in totp.get("backup_hashes", []):
        await mongo[USERS].update_one(
            {"_id": claims.user_id}, {"$pull": {"totp.backup_hashes": candidate}}
        )
        return

    raise api_error(ErrorCode.TOTP_INVALID, field="totp_code")
