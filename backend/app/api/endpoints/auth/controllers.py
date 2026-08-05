from datetime import timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError
from redis.asyncio import Redis

from app.api.endpoints.auth import constants as c
from app.api.endpoints.auth.models import (
    DeviceInfo,
    SigninWithDeviceRequest,
    SignupRequest,
)
from app.api.endpoints.auth.utils import (
    DUMMY_PASSWORD_HASH,
    device_fingerprint,
    is_valid_username,
    new_avatar_seed,
    serialize_user,
)
from app.config import Settings
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id, new_referral_code
from app.core.password import (
    hash_password,
    needs_rehash,
    validate_password_strength,
    verify_password,
)
from app.core.time import to_wire, utc_now
from app.core.tokens import (
    create_access_token,
    hash_refresh_token,
    new_family_id,
    new_refresh_token,
)
from app.db import keys


async def _allocate_referral_code(mongo: AsyncIOMotorDatabase) -> str:
    for _ in range(c.REFERRAL_CODE_ATTEMPTS):
        code = new_referral_code()
        if not await mongo[c.USERS].find_one({"referral_code": code}, {"_id": 1}):
            return code
    raise api_error(ErrorCode.INTERNAL_ERROR)


async def _issue_session(
    *,
    user: dict[str, Any],
    settings: Settings,
    redis: Redis,
    family_id: str | None = None,
) -> dict[str, Any]:
    family = family_id or new_family_id()
    access = create_access_token(
        user_id=user["_id"],
        role=user["role"],
        family_id=family,
        secret=settings.JWT_SECRET,
        ttl=timedelta(minutes=settings.ACCESS_TOKEN_TTL_MINUTES),
    )
    refresh = new_refresh_token()
    refresh_ttl = timedelta(days=settings.REFRESH_TOKEN_TTL_DAYS)
    token_hash = hash_refresh_token(refresh)

    pipe = redis.pipeline()
    pipe.set(
        keys.refresh_token(token_hash),
        f"{user['_id']}|{family}",
        ex=int(refresh_ttl.total_seconds()),
    )
    pipe.sadd(keys.refresh_family(family), token_hash)
    pipe.expire(keys.refresh_family(family), int(refresh_ttl.total_seconds()))
    pipe.sadd(keys.user_sessions(user["_id"]), family)
    pipe.expire(keys.user_sessions(user["_id"]), int(refresh_ttl.total_seconds()))
    await pipe.execute()

    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_TTL_MINUTES * 60,
    }


def _ensure_usable(user: dict[str, Any]) -> None:
    if user.get("blocked"):
        raise api_error(ErrorCode.ACCOUNT_BLOCKED)
    if user.get("status") == "pending_deletion":
        raise api_error(ErrorCode.ACCOUNT_DEACTIVATED)


async def username_available(username: str, *, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    if not is_valid_username(username):
        raise api_error(ErrorCode.USERNAME_INVALID, field="username")
    existing = await mongo[c.USERS].find_one({"username_lower": username}, {"_id": 1})
    return {"available": existing is None}


async def signup(
    body: SignupRequest,
    *,
    mongo: AsyncIOMotorDatabase,
    redis: Redis,
    settings: Settings,
) -> dict[str, Any]:
    if not is_valid_username(body.username):
        raise api_error(ErrorCode.USERNAME_INVALID, field="username")
    if not body.tnc_accepted:
        raise api_error(ErrorCode.TNC_REQUIRED, field="tnc_accepted")

    try:
        validate_password_strength(body.password, username=body.username)
    except ValueError as exc:
        raise api_error(ErrorCode.PASSWORD_TOO_WEAK, message=str(exc), field="password") from exc

    if body.referral_code:
        referrer = await mongo[c.USERS].find_one({"referral_code": body.referral_code}, {"_id": 1})
        if referrer is None:
            raise api_error(ErrorCode.REFERRAL_CODE_INVALID, field="referral_code")

    now = utc_now()
    user = {
        "_id": new_id("usr"),
        "username": body.username,
        "username_lower": body.username,
        "display_name": body.username,
        "avatar_seed": new_avatar_seed(),
        "password_hash": hash_password(body.password),
        "role": "user",
        "status": "active",
        "blocked": False,
        "blocked_reason": None,
        "blocked_at": None,
        "referral_code": await _allocate_referral_code(mongo),
        "referred_by": body.referral_code,
        "login_info": None,
        "tnc": {
            "accepted": True,
            "version": c.TNC_VERSION,
            "accepted_at": now,
        },
        "interests": [],
        "bio": None,
        "counts": dict(c.DEFAULT_COUNTS),
        "prefs": dict(c.DEFAULT_PREFS),
        "onboarding": dict(c.DEFAULT_ONBOARDING),
        "last_login_at": None,
        "last_active_at": None,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }

    try:
        await mongo[c.USERS].insert_one(user)
    except DuplicateKeyError as exc:
        raise api_error(ErrorCode.USERNAME_TAKEN, field="username") from exc

    tokens = await _issue_session(user=user, settings=settings, redis=redis)
    return {"user": serialize_user(user), "tokens": tokens, "keys_required": True}


async def signin(
    body: SigninWithDeviceRequest,
    *,
    ip_prefix: str,
    mongo: AsyncIOMotorDatabase,
    redis: Redis,
    settings: Settings,
) -> dict[str, Any]:
    user = await mongo[c.USERS].find_one({"username_lower": body.username})

    if user is None:
        verify_password(body.password, DUMMY_PASSWORD_HASH)
        raise api_error(ErrorCode.INVALID_CREDENTIALS)

    if not verify_password(body.password, user["password_hash"]):
        raise api_error(ErrorCode.INVALID_CREDENTIALS)

    _ensure_usable(user)

    now = utc_now()
    device = body.device or DeviceInfo()
    login_info = {
        "logged_in_at": now,
        "ip_prefix": ip_prefix,
        "platform": device.platform,
        "os_version": device.os_version,
        "app_version": device.app_version,
        "device_model": device.device_model,
        "fingerprint": device_fingerprint(
            platform=device.platform,
            os_version=device.os_version,
            app_version=device.app_version,
            device_model=device.device_model,
        ),
    }

    update: dict[str, Any] = {
        "login_info": login_info,
        "last_login_at": now,
        "last_active_at": now,
        "updated_at": now,
    }
    if needs_rehash(user["password_hash"]):
        update["password_hash"] = hash_password(body.password)

    await mongo[c.USERS].update_one({"_id": user["_id"]}, {"$set": update})
    user.update(update)

    await _record_device(user_id=user["_id"], login_info=login_info, mongo=mongo, now=now)

    tokens = await _issue_session(user=user, settings=settings, redis=redis)
    return {"user": serialize_user(user), "tokens": tokens}


async def _record_device(
    *, user_id: str, login_info: dict[str, Any], mongo: AsyncIOMotorDatabase, now
) -> None:
    label_parts = [login_info["device_model"], login_info["os_version"]]
    label = " · ".join([part for part in label_parts if part]) or login_info["platform"]
    await mongo[c.DEVICES].update_one(
        {"user_id": user_id, "fingerprint": login_info["fingerprint"]},
        {
            "$set": {
                "label": label,
                "platform": login_info["platform"],
                "last_seen_at": now,
                "updated_at": now,
            },
            "$setOnInsert": {
                "_id": new_id("dev"),
                "user_id": user_id,
                "fingerprint": login_info["fingerprint"],
                "first_seen_at": now,
                "trusted": False,
                "created_at": now,
            },
        },
        upsert=True,
    )


async def refresh(
    token: str, *, mongo: AsyncIOMotorDatabase, redis: Redis, settings: Settings
) -> dict[str, Any]:
    token_hash = hash_refresh_token(token)
    record = await redis.get(keys.refresh_token(token_hash))

    if record is None:
        if await redis.exists(keys.revoked_refresh(token_hash)):
            revoked = await redis.get(keys.revoked_refresh(token_hash))
            if revoked:
                await _revoke_family(revoked, redis=redis)
            raise api_error(ErrorCode.TOKEN_REUSED)
        raise api_error(ErrorCode.TOKEN_INVALID)

    user_id, family_id = record.split("|", 1)
    user = await mongo[c.USERS].find_one({"_id": user_id})
    if user is None:
        raise api_error(ErrorCode.TOKEN_INVALID)
    _ensure_usable(user)

    refresh_ttl = int(timedelta(days=settings.REFRESH_TOKEN_TTL_DAYS).total_seconds())
    pipe = redis.pipeline()
    pipe.delete(keys.refresh_token(token_hash))
    pipe.srem(keys.refresh_family(family_id), token_hash)
    pipe.set(keys.revoked_refresh(token_hash), family_id, ex=refresh_ttl)
    await pipe.execute()

    tokens = await _issue_session(user=user, settings=settings, redis=redis, family_id=family_id)
    return {"tokens": tokens}


async def _revoke_family(family_id: str, *, redis: Redis) -> None:
    hashes = await redis.smembers(keys.refresh_family(family_id))
    pipe = redis.pipeline()
    for token_hash in hashes:
        pipe.delete(keys.refresh_token(token_hash))
    pipe.delete(keys.refresh_family(family_id))
    await pipe.execute()


async def signout(
    *, claims, redis: Redis, settings: Settings, refresh_token_value: str | None
) -> dict[str, Any]:
    await _revoke_family(claims.family_id, redis=redis)
    await redis.srem(keys.user_sessions(claims.user_id), claims.family_id)

    remaining = int((claims.expires_at - utc_now()).total_seconds())
    if remaining > 0:
        await redis.set(keys.access_denylist(claims.jti), "1", ex=remaining)

    if refresh_token_value:
        token_hash = hash_refresh_token(refresh_token_value)
        await redis.delete(keys.refresh_token(token_hash))

    return {"signed_out": True}


async def signout_all(*, claims, redis: Redis) -> dict[str, Any]:
    families = await redis.smembers(keys.user_sessions(claims.user_id))
    for family_id in families:
        await _revoke_family(family_id, redis=redis)
    await redis.delete(keys.user_sessions(claims.user_id))

    remaining = int((claims.expires_at - utc_now()).total_seconds())
    if remaining > 0:
        await redis.set(keys.access_denylist(claims.jti), "1", ex=remaining)

    return {"signed_out": True, "sessions_revoked": len(families)}


async def me(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[c.USERS].find_one({"_id": claims.user_id}, c.PUBLIC_USER_PROJECTION)
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)
    _ensure_usable(user)
    return {"user": serialize_user(user)}


async def list_sessions(*, claims, mongo: AsyncIOMotorDatabase, redis: Redis) -> dict[str, Any]:
    family_ids = sorted(await redis.smembers(keys.user_sessions(claims.user_id)))
    devices = {
        doc["fingerprint"]: doc async for doc in mongo[c.DEVICES].find({"user_id": claims.user_id})
    }
    latest = max(devices.values(), key=lambda d: d["last_seen_at"], default=None)

    items = []
    for family_id in family_ids:
        token_count = await redis.scard(keys.refresh_family(family_id))
        if token_count == 0:
            continue
        items.append(
            {
                "family_id": family_id,
                "is_current": family_id == claims.family_id,
                "label": (latest or {}).get("label", "This device"),
                "platform": (latest or {}).get("platform", "web"),
                "last_seen_at": to_wire((latest or {}).get("last_seen_at")),
            }
        )
    return {"items": items}


async def revoke_session(family_id: str, *, claims, redis: Redis) -> dict[str, Any]:
    if not await redis.sismember(keys.user_sessions(claims.user_id), family_id):
        raise api_error(ErrorCode.SESSION_NOT_FOUND)

    await _revoke_family(family_id, redis=redis)
    await redis.srem(keys.user_sessions(claims.user_id), family_id)
    return {"revoked": True, "family_id": family_id}
