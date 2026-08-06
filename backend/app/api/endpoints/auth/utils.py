import hashlib
import re
import secrets
from typing import Any

from app.api.endpoints.auth.constants import (
    PUBLIC_USER_PROJECTION,
    RESERVED_USERNAMES,
    USERNAME_MAX_LENGTH,
    USERNAME_MIN_LENGTH,
    USERNAME_PATTERN,
)
from app.core.time import to_wire

_USERNAME_RE = re.compile(USERNAME_PATTERN)

DUMMY_PASSWORD_HASH = (
    "$argon2id$v=19$m=65536,t=3,p=2$c3RvcnlkdW1teXNhbHQ$YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY"
)


def is_valid_username(username: str) -> bool:
    if not USERNAME_MIN_LENGTH <= len(username) <= USERNAME_MAX_LENGTH:
        return False
    if username in RESERVED_USERNAMES:
        return False
    return bool(_USERNAME_RE.fullmatch(username))


def new_avatar_seed() -> str:
    return secrets.token_hex(8)


def device_fingerprint(
    *, platform: str, os_version: str | None, app_version: str | None, device_model: str | None
) -> str:
    raw = "|".join([platform, os_version or "", app_version or "", device_model or ""])
    return hashlib.sha256(raw.encode()).hexdigest()[:32]


def serialize_user(
    doc: dict[str, Any], *, email_masked: str | None = None, email_verified: bool = False
) -> dict[str, Any]:
    login_info = doc.get("login_info")
    if login_info:
        login_info = {**login_info, "logged_in_at": to_wire(login_info.get("logged_in_at"))}

    return {
        "user_id": doc["_id"],
        "username": doc["username"],
        "display_name": doc["display_name"],
        "avatar_seed": doc["avatar_seed"],
        "role": doc["role"],
        "status": doc["status"],
        "blocked": doc.get("blocked", False),
        "referral_code": doc["referral_code"],
        "referred_by": doc.get("referred_by"),
        "bio": doc.get("bio"),
        "interests": doc.get("interests", []),
        "counts": doc.get("counts", {}),
        "prefs": doc.get("prefs", {}),
        "onboarding": doc.get("onboarding", {}),
        "login_info": login_info,
        "email_masked": email_masked,
        "email_verified": email_verified,
        "created_at": to_wire(doc["created_at"]),
        "last_login_at": to_wire(doc.get("last_login_at")),
    }


__all__ = [
    "DUMMY_PASSWORD_HASH",
    "PUBLIC_USER_PROJECTION",
    "device_fingerprint",
    "is_valid_username",
    "new_avatar_seed",
    "serialize_user",
]
