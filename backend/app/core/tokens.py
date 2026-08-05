import hashlib
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from pydantic import BaseModel

from app.core.time import to_storage, utc_now

JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_TTL = timedelta(minutes=30)
REFRESH_TOKEN_TTL = timedelta(days=30)
REFRESH_TOKEN_BYTES = 32


class TokenError(Exception):
    pass


class AccessClaims(BaseModel):
    user_id: str
    role: str
    family_id: str
    jti: str
    issued_at: datetime
    expires_at: datetime


def create_access_token(
    *,
    user_id: str,
    role: str,
    family_id: str,
    secret: str,
    ttl: timedelta = ACCESS_TOKEN_TTL,
) -> str:
    issued_at = utc_now()
    payload = {
        "sub": user_id,
        "role": role,
        "fam": family_id,
        "jti": secrets.token_urlsafe(16),
        "iat": issued_at,
        "exp": issued_at + ttl,
    }
    return jwt.encode(payload, secret, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str, *, secret: str) -> AccessClaims:
    try:
        payload = jwt.decode(token, secret, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError as exc:
        raise TokenError("Access token expired.") from exc
    except jwt.PyJWTError as exc:
        raise TokenError("Access token invalid.") from exc

    return AccessClaims(
        user_id=payload["sub"],
        role=payload["role"],
        family_id=payload["fam"],
        jti=payload["jti"],
        issued_at=to_storage(datetime.fromtimestamp(payload["iat"], tz=UTC)),
        expires_at=to_storage(datetime.fromtimestamp(payload["exp"], tz=UTC)),
    )


def new_refresh_token() -> str:
    return secrets.token_urlsafe(REFRESH_TOKEN_BYTES)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def new_family_id() -> str:
    return f"fam_{secrets.token_urlsafe(12)}"
