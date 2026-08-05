from typing import Annotated

from fastapi import Depends, Request
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import Settings
from app.logging import get_logger

logger = get_logger("story.db.mongo")

CONNECT_TIMEOUT_MS = 5000


class MongoUnavailableError(RuntimeError):
    pass


async def connect_mongo(app, settings: Settings) -> None:
    client: AsyncIOMotorClient = AsyncIOMotorClient(
        settings.MONGODB_URI,
        serverSelectionTimeoutMS=CONNECT_TIMEOUT_MS,
        connectTimeoutMS=CONNECT_TIMEOUT_MS,
        tz_aware=True,
    )
    try:
        result = await client.admin.command("ping")
    except Exception as exc:
        raise MongoUnavailableError(
            f"MongoDB unreachable at {settings.MONGODB_URI}: {type(exc).__name__}: {exc}"
        ) from exc

    if not result.get("ok"):
        raise MongoUnavailableError(f"MongoDB ping returned {result!r}.")

    app.state.mongo_client = client
    app.state.mongo_db = client[settings.MONGODB_DB_NAME]
    logger.info("mongo_connected", service="mongodb", count=1)


async def disconnect_mongo(app) -> None:
    client = getattr(app.state, "mongo_client", None)
    if client is not None:
        client.close()
        app.state.mongo_client = None
        app.state.mongo_db = None


async def ping_mongo(app) -> bool:
    client = getattr(app.state, "mongo_client", None)
    if client is None:
        return False
    try:
        return bool((await client.admin.command("ping")).get("ok"))
    except Exception:
        return False


def _get_db(request: Request) -> AsyncIOMotorDatabase:
    return request.app.state.mongo_db


MongoDatabase = Annotated[AsyncIOMotorDatabase, Depends(_get_db)]
