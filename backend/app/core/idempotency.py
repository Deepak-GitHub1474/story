import hashlib
import json
from typing import Any

from fastapi import Request
from redis.asyncio import Redis

from app.db.keys import NAMESPACE

TTL_SECONDS = 86400
HEADER = "idempotency-key"
MAX_KEY_LENGTH = 128


def cache_key(user_id: str, route: str, key: str) -> str:
    digest = hashlib.sha256(f"{route}|{key}".encode()).hexdigest()
    return f"{NAMESPACE}:IDEM:{user_id}:{digest}"


def request_key(request: Request) -> str | None:
    value = request.headers.get(HEADER, "").strip()
    if not value or len(value) > MAX_KEY_LENGTH:
        return None
    return value


async def replay(request: Request, *, user_id: str, redis: Redis) -> dict[str, Any] | None:
    key = request_key(request)
    if key is None:
        return None

    cached = await redis.get(cache_key(user_id, request.url.path, key))
    return json.loads(cached) if cached else None


async def remember(
    request: Request, *, user_id: str, redis: Redis, payload: dict[str, Any]
) -> None:
    key = request_key(request)
    if key is None:
        return

    await redis.set(
        cache_key(user_id, request.url.path, key),
        json.dumps(payload, default=str),
        ex=TTL_SECONDS,
    )
