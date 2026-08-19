from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.stories.constants import LIKERS_PREVIEW
from app.api.endpoints.stories.controllers import people_who_liked
from app.logging import get_logger

logger = get_logger("story.db.backfill")

LIKERS_MARK = "likers_preview_v1"
IDENTITY_MARK = "identity_by_reference_v1"
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
                    "likers": [person["user_id"] for person in people]
                }
            },
        )
        filled += 1

    await db[MIGRATIONS].insert_one({"_id": LIKERS_MARK, "stories": filled})
    logger.info("backfill_likers", stories=filled)
    return filled


async def backfill_identity(db: AsyncIOMotorDatabase) -> int:
    """Move stored identity from copies to references.

    A story, a comment and an activity row each used to carry the author's
    name and face frozen at the moment they were written. They now carry an
    id and nothing else, so this drops the copies and turns the liked-by
    row into a list of ids. Every step is filtered so it is safe to re-run.
    """
    if await db[MIGRATIONS].find_one({"_id": IDENTITY_MARK}, {"_id": 1}) is not None:
        return 0

    likers = await db["stories"].update_many(
        {"likers.0": {"$type": "object"}},
        [
            {
                "$set": {
                    "likers": {
                        "$map": {
                            "input": "$likers",
                            "as": "person",
                            "in": "$$person.user_id",
                        }
                    }
                }
            }
        ],
    )

    touched = 0
    for collection, field in (
        ("stories", "author_snapshot"),
        ("comments", "author_snapshot"),
        ("notifications", "actor_snapshot"),
    ):
        result = await db[collection].update_many(
            {field: {"$exists": True}}, {"$unset": {field: ""}}
        )
        touched += result.modified_count

    await db[MIGRATIONS].insert_one(
        {"_id": IDENTITY_MARK, "rows": touched, "liked_by_rows": likers.modified_count}
    )
    logger.info("backfill_identity", rows=touched, count=likers.modified_count)
    return touched
