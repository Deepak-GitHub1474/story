import hashlib
import secrets
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from redis.asyncio import Redis

from app.api.endpoints.auth.constants import USERS
from app.api.endpoints.email import otp as otp_service
from app.api.endpoints.email.models import (
    AddEmailRequest,
    RemoveEmailRequest,
    ResetCompleteRequest,
    ResetVerifyRequest,
)
from app.config import Settings
from app.core.crypto import blind_index, decrypt_email, encrypt_email, mask_email
from app.core.errors import ErrorCode, api_error
from app.core.password import hash_password, validate_password_strength, verify_password
from app.core.time import utc_now
from app.db import keys
from app.ports.mail import MailPort

USER_KEYS = "user_keys"

GENERIC_RESET_MESSAGE = "If that account can be recovered, a code is on its way."


async def _keys_document(user_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    document = await mongo[USER_KEYS].find_one({"_id": user_id})
    return document or {"_id": user_id, "user_id": user_id}


async def add_email(
    body: AddEmailRequest,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    redis: Redis,
    settings: Settings,
    mail: MailPort,
) -> dict[str, Any]:
    index = blind_index(body.email, key=settings.EMAIL_INDEX_KEY)

    existing = await mongo[USER_KEYS].find_one(
        {"email_index": index, "email_verified": True}, {"_id": 1}
    )
    if existing is not None and existing["_id"] != claims.user_id:
        raise api_error(ErrorCode.EMAIL_IN_USE, field="email")

    masked = mask_email(body.email)
    now = utc_now()
    await mongo[USER_KEYS].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "user_id": claims.user_id,
                "email_index": index,
                "email_ciphertext": encrypt_email(body.email, key=settings.EMAIL_ENCRYPTION_KEY),
                "email_masked": masked,
                "email_verified": False,
                "email_verified_at": None,
                "email_added_at": now,
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )

    code = await otp_service.issue(
        key=keys.email_otp(claims.user_id),
        cooldown_key=keys.otp_cooldown(claims.user_id),
        redis=redis,
        settings=settings,
        enforce_cooldown=False,
    )
    await mail.send_otp(email=body.email, otp=code, purpose="verify_email")

    return {"email_masked": masked, "email_verified": False}


async def resend_otp(
    *, claims, mongo: AsyncIOMotorDatabase, redis: Redis, settings: Settings, mail: MailPort
) -> dict[str, Any]:
    document = await _keys_document(claims.user_id, mongo)
    if not document.get("email_ciphertext"):
        raise api_error(ErrorCode.EMAIL_NOT_SET)

    address = decrypt_email(document["email_ciphertext"], key=settings.EMAIL_ENCRYPTION_KEY)
    code = await otp_service.issue(
        key=keys.email_otp(claims.user_id),
        cooldown_key=keys.otp_cooldown(claims.user_id),
        redis=redis,
        settings=settings,
        enforce_cooldown=True,
    )
    await mail.send_otp(email=address, otp=code, purpose="verify_email")

    return {"email_masked": document.get("email_masked"), "email_verified": False}


async def verify_email(
    otp: str, *, claims, mongo: AsyncIOMotorDatabase, redis: Redis, settings: Settings
) -> dict[str, Any]:
    document = await _keys_document(claims.user_id, mongo)
    if not document.get("email_ciphertext"):
        raise api_error(ErrorCode.EMAIL_NOT_SET)

    await otp_service.verify(
        key=keys.email_otp(claims.user_id), otp=otp, redis=redis, settings=settings
    )

    now = utc_now()
    await mongo[USER_KEYS].update_one(
        {"_id": claims.user_id},
        {"$set": {"email_verified": True, "email_verified_at": now, "updated_at": now}},
    )
    return {"email_verified": True, "email_masked": document.get("email_masked")}


async def remove_email(
    body: RemoveEmailRequest, *, claims, mongo: AsyncIOMotorDatabase, redis: Redis
) -> dict[str, Any]:
    user = await mongo[USERS].find_one({"_id": claims.user_id}, {"password_hash": 1})
    if user is None or not verify_password(body.password, user["password_hash"]):
        raise api_error(ErrorCode.INVALID_CREDENTIALS, field="password")

    await mongo[USER_KEYS].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "email_index": None,
                "email_ciphertext": None,
                "email_masked": None,
                "email_verified": False,
                "email_verified_at": None,
                "updated_at": utc_now(),
            }
        },
    )
    await redis.delete(keys.email_otp(claims.user_id))
    return {"email_removed": True}


async def request_reset(
    username: str,
    *,
    mongo: AsyncIOMotorDatabase,
    redis: Redis,
    settings: Settings,
    mail: MailPort,
) -> dict[str, Any]:
    user = await mongo[USERS].find_one(
        {"username_lower": username.lower(), "deleted_at": None}, {"_id": 1}
    )
    if user is None:
        return {"sent": True}

    document = await mongo[USER_KEYS].find_one(
        {"_id": user["_id"], "email_verified": True}, {"email_ciphertext": 1}
    )
    if document is None or not document.get("email_ciphertext"):
        return {"sent": True}

    address = decrypt_email(document["email_ciphertext"], key=settings.EMAIL_ENCRYPTION_KEY)
    code = await otp_service.issue(
        key=keys.reset_otp(user["_id"]),
        cooldown_key=keys.otp_cooldown(user["_id"]),
        redis=redis,
        settings=settings,
        enforce_cooldown=False,
    )
    await mail.send_otp(email=address, otp=code, purpose="password_reset")
    return {"sent": True}


async def verify_reset(
    body: ResetVerifyRequest, *, mongo: AsyncIOMotorDatabase, redis: Redis, settings: Settings
) -> dict[str, Any]:
    user = await mongo[USERS].find_one(
        {"username_lower": body.username.lower(), "deleted_at": None}, {"_id": 1}
    )
    if user is None:
        raise api_error(ErrorCode.OTP_INVALID)

    await otp_service.verify(
        key=keys.reset_otp(user["_id"]), otp=body.otp, redis=redis, settings=settings
    )

    token = secrets.token_urlsafe(32)
    await redis.set(
        keys.reset_token(hashlib.sha256(token.encode()).hexdigest()),
        user["_id"],
        ex=settings.RESET_TOKEN_TTL_SECONDS,
    )
    return {"reset_token": token, "expires_in": settings.RESET_TOKEN_TTL_SECONDS}


async def complete_reset(
    body: ResetCompleteRequest,
    *,
    mongo: AsyncIOMotorDatabase,
    redis: Redis,
    settings: Settings,
) -> dict[str, Any]:
    if not body.acknowledged_vault_loss:
        raise api_error(ErrorCode.VAULT_LOSS_NOT_ACKNOWLEDGED, field="acknowledged_vault_loss")

    token_key = keys.reset_token(hashlib.sha256(body.reset_token.encode()).hexdigest())
    user_id = await redis.get(token_key)
    if user_id is None:
        raise api_error(ErrorCode.RESET_TOKEN_INVALID)

    user = await mongo[USERS].find_one({"_id": user_id}, {"username": 1})
    if user is None:
        raise api_error(ErrorCode.RESET_TOKEN_INVALID)

    try:
        validate_password_strength(body.new_password, username=user["username"])
    except ValueError as exc:
        raise api_error(
            ErrorCode.PASSWORD_TOO_WEAK, message=str(exc), field="new_password"
        ) from exc

    await redis.delete(token_key)
    await mongo[USERS].update_one(
        {"_id": user_id},
        {
            "$set": {
                "password_hash": hash_password(body.new_password),
                "updated_at": utc_now(),
            }
        },
    )
    await mongo[USER_KEYS].update_one({"_id": user_id}, {"$inc": {"umk_version": 1}}, upsert=True)

    families = await redis.smembers(keys.user_sessions(user_id))
    for family_id in families:
        hashes = await redis.smembers(keys.refresh_family(family_id))
        for token_hash in hashes:
            await redis.delete(keys.refresh_token(token_hash))
        await redis.delete(keys.refresh_family(family_id))
    await redis.delete(keys.user_sessions(user_id))
    await redis.set(keys.reset_marker(user_id), "1", ex=settings.ACCESS_TOKEN_TTL_MINUTES * 60)

    return {"password_reset": True}
