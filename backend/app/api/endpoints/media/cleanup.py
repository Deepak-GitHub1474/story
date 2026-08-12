import re

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.ports.storage import StoragePort

PROFILE = "media"
STORIES = "stories"

MEDIA_ID = re.compile(r"^med_[0-9A-HJKMNP-TV-Z]{26}$")


def key_for(url: str) -> str | None:
    media_id = url.rsplit("/", 1)[-1]
    return f"media/{media_id}" if MEDIA_ID.match(media_id) else None


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
        removed += 1
    return removed
