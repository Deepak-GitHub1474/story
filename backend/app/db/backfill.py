from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.stories.constants import LIKERS_PREVIEW
from app.api.endpoints.stories.controllers import people_who_liked
from app.logging import get_logger

logger = get_logger("story.db.backfill")

LIKERS_MARK = "likers_preview_v1"
MIGRATIONS = "migrations"


async def backfill_likers(db: AsyncIOMotorDatabase) -> int:
    if await db[MIGRATIONS].find_one({"_id": LIKERS_MARK}, {"_id": 1}) is not None:
        return 0

    filled = 0
    stories = db["stories"].find(
        {"counts.likes": {"$gt": 0}, "likers": {"$exists": False}}, {"_id": 1}
    )
    async for story in stories:
        people, _, _ = await people_who_liked(story["_id"], db, limit=LIKERS_PREVIEW)
        await db["stories"].update_one(
            {"_id": story["_id"]},
            {
                "$set": {
                    "likers": [
                        {
                            "user_id": person["user_id"],
                            "display_name": person["display_name"],
                            "avatar_seed": person["avatar_seed"],
                            "username": person["username"],
                        }
                        for person in people
                    ]
                }
            },
        )
        filled += 1

    await db[MIGRATIONS].insert_one({"_id": LIKERS_MARK, "stories": filled})
    logger.info("backfill_likers", stories=filled)
    return filled
