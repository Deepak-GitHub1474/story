from typing import Annotated

import redis.asyncio as aioredis
from fastapi import Depends, Request

from app.config import Settings
from app.logging import get_logger

logger = get_logger("story.db.redis")

CONNECT_TIMEOUT_SECONDS = 5


class RedisUnavailableError(RuntimeError):
    pass


async def connect_redis(app, settings: Settings) -> None:
    client = aioredis.from_url(
        settings.REDIS_URL,
        decode_responses=True,
        socket_connect_timeout=CONNECT_TIMEOUT_SECONDS,
        socket_timeout=CONNECT_TIMEOUT_SECONDS,
        health_check_interval=30,
    )
    try:
        pong = await client.ping()
    except Exception as exc:
        raise RedisUnavailableError(
            f"Redis unreachable at {settings.REDIS_URL}: {type(exc).__name__}: {exc}"
        ) from exc

    if not pong:
        raise RedisUnavailableError("Redis PING did not return PONG.")

    app.state.redis = client
    logger.info("redis_connected", service="redis", count=1)


async def disconnect_redis(app) -> None:
    client = getattr(app.state, "redis", None)
    if client is not None:
        await client.aclose()
        app.state.redis = None


async def ping_redis(app) -> bool:
    client = getattr(app.state, "redis", None)
    if client is None:
        return False
    try:
        return bool(await client.ping())
    except Exception:
        return False


def _get_redis(request: Request) -> aioredis.Redis:
    return request.app.state.redis


RedisClient = Annotated[aioredis.Redis, Depends(_get_redis)]
