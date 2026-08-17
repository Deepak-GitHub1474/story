import re
from datetime import timedelta

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.time import utc_now
from app.ports.storage import StoragePort

PROFILE = "media"
STORIES = "stories"
MEDIA = "media"

MEDIA_ID = re.compile(r"^med_[0-9A-HJKMNP-TV-Z]{26}$")


def key_for(url: str) -> str | None:
    media_id = url.rsplit("/", 1)[-1]
    return f"media/{media_id}" if MEDIA_ID.match(media_id) else None


def url_for(media_id: str) -> str:
    return f"/v1/media/{media_id}"


async def drop_unused(
    urls: list[str], *, mongo: AsyncIOMotorDatabase, storage: StoragePort
) -> int:
    removed = 0
    for url in dict.fromkeys(urls):
        key = key_for(url)
        if key is None:
            continue

        still_used = await mongo[STORIES].count_documents(
            {"images": url, "deleted_at": None}, limit=1
        )
        if still_used:
            continue

        await storage.delete(profile=PROFILE, key=key)
        await mongo[MEDIA].delete_one({"_id": url.rsplit("/", 1)[-1]})
        removed += 1
    return removed


async def sweep_orphans(
    *, mongo: AsyncIOMotorDatabase, storage: StoragePort, grace_seconds: int
) -> int:
    cutoff = utc_now() - timedelta(seconds=grace_seconds)
    candidates = await mongo[MEDIA].distinct("_id", {"created_at": {"$lt": cutoff}})
    if not candidates:
        return 0

    return await drop_unused(
        [url_for(media_id) for media_id in candidates], mongo=mongo, storage=storage
    )
