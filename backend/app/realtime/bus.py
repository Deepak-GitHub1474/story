import asyncio
import json
from typing import Any

from redis.asyncio import Redis

from app.logging import get_logger
from app.realtime.hub import hub

logger = get_logger("story.realtime.bus")

CHANNEL = "ST:WS"


async def publish(redis: Redis, user_ids: list[str], payload: dict[str, Any]) -> None:
    await redis.publish(
        CHANNEL, json.dumps({"targets": user_ids, "payload": payload})
    )


async def listen(redis: Redis) -> None:
    pubsub = redis.pubsub(ignore_subscribe_messages=True)
    await pubsub.subscribe(CHANNEL)

    try:
        async for message in pubsub.listen():
            if message.get("type") != "message":
                continue
            try:
                envelope = json.loads(message["data"])
            except (ValueError, TypeError):
                continue
            await hub.broadcast(envelope.get("targets", []), envelope.get("payload", {}))
    except asyncio.CancelledError:
        await pubsub.unsubscribe(CHANNEL)
        raise
    except Exception:
        logger.error("realtime_bus_stopped", code="realtime_bus_stopped")
