from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.auth.constants import PUBLIC_USER_PROJECTION, USERS
from app.api.endpoints.auth.utils import new_avatar_seed, serialize_user
from app.api.endpoints.connections import controllers as connection_controllers
from app.api.endpoints.users.models import ChangePasswordRequest, UpdateProfileRequest
from app.api.endpoints.users.utils import contains_link, serialize_public_user
from app.core.errors import ErrorCode, api_error
from app.core.password import hash_password, validate_password_strength, verify_password
from app.core.time import utc_now

PUBLIC_PROFILE_PROJECTION = {
    "_id": 1,
    "username": 1,
    "display_name": 1,
    "avatar_seed": 1,
    "bio": 1,
    "interests": 1,
    "counts": 1,
    "blocked": 1,
    "deleted_at": 1,
}


async def _load(user_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[USERS].find_one({"_id": user_id}, PUBLIC_USER_PROJECTION)
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)
    return user


async def update_profile(
    body: UpdateProfileRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    update: dict[str, Any] = {"updated_at": utc_now()}

    if body.display_name is not None:
        update["display_name"] = body.display_name

    if body.bio is not None:
        if contains_link(body.bio):
            raise api_error(
                ErrorCode.BIO_LINK_NOT_ALLOWED,
                field="bio",
            )
        update["bio"] = body.bio or None

    if body.interests is not None:
        slugs = list(dict.fromkeys(body.interests))
        known = await mongo["interests"].distinct("_id", {"_id": {"$in": slugs}})
        unknown = [slug for slug in slugs if slug not in known]
        if unknown:
            raise api_error(
                ErrorCode.INTEREST_UNKNOWN,
                message=f"Unknown interest: {unknown[0]}.",
                field="interests",
            )
        update["interests"] = slugs
        update["onboarding.interests_done"] = True

    if body.prefs is not None:
        for key, value in body.prefs.model_dump(exclude_none=True).items():
            update[f"prefs.{key}"] = value

    await mongo[USERS].update_one({"_id": claims.user_id}, {"$set": update})
    return {"user": serialize_user(await _load(claims.user_id, mongo))}


async def regenerate_avatar(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    await mongo[USERS].update_one(
        {"_id": claims.user_id},
        {"$set": {"avatar_seed": new_avatar_seed(), "updated_at": utc_now()}},
    )
    return {"user": serialize_user(await _load(claims.user_id, mongo))}


async def public_profile(username: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[USERS].find_one(
        {"username_lower": username.lower(), "deleted_at": None},
        PUBLIC_PROFILE_PROJECTION,
    )
    if user is None or user.get("blocked"):
        raise api_error(ErrorCode.USER_NOT_FOUND)

    is_me = user["_id"] == claims.user_id
    following = (
        False
        if is_me
        else await connection_controllers.is_following(claims.user_id, user["_id"], mongo)
    )
    return {"user": serialize_public_user(user, is_following=following, is_me=is_me)}


async def change_password(
    body: ChangePasswordRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    user = await mongo[USERS].find_one({"_id": claims.user_id}, {"password_hash": 1, "username": 1})
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)

    if not verify_password(body.current_password, user["password_hash"]):
        raise api_error(ErrorCode.INVALID_CREDENTIALS, field="current_password")

    try:
        validate_password_strength(body.new_password, username=user["username"])
    except ValueError as exc:
        raise api_error(
            ErrorCode.PASSWORD_TOO_WEAK, message=str(exc), field="new_password"
        ) from exc

    await mongo[USERS].update_one(
        {"_id": claims.user_id},
        {"$set": {"password_hash": hash_password(body.new_password), "updated_at": utc_now()}},
    )
    return {"password_changed": True}
