from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.stories.utils import new_slug
from app.core.time import utc_now
from app.logging import get_logger

logger = get_logger("story.workers.maintenance")

SWEEP_BATCH = 200


async def publish_scheduled_stories(mongo: AsyncIOMotorDatabase) -> int:
    now = utc_now()
    due = (
        await mongo["stories"]
        .find(
            {
                "visibility": "scheduled",
                "scheduled_for": {"$lte": now},
                "deleted_at": None,
            },
            {"_id": 1, "author_id": 1, "slug": 1, "community_slug": 1},
        )
        .limit(SWEEP_BATCH)
        .to_list(length=SWEEP_BATCH)
    )

    published = 0
    for story in due:
        update: dict[str, Any] = {
            "visibility": "public",
            "published_at": now.replace(second=0, microsecond=0),
            "moderation.state": "allowed",
            "updated_at": now,
        }
        if not story.get("slug"):
            update["slug"] = new_slug()

        result = await mongo["stories"].update_one(
            {"_id": story["_id"], "visibility": "scheduled"}, {"$set": update}
        )
        if result.modified_count == 0:
            continue

        published += 1
        await mongo["users"].update_one(
            {"_id": story["author_id"]}, {"$inc": {"counts.stories": 1}}
        )
        if story.get("community_slug"):
            await mongo["communities"].update_one(
                {"slug": story["community_slug"]}, {"$inc": {"counts.stories": 1}}
            )

    if published:
        logger.info("scheduled_published", count=published)
    return published


async def reconcile_counts(mongo: AsyncIOMotorDatabase) -> dict[str, int]:
    repaired = {"users": 0, "stories": 0, "communities": 0}

    async for user in mongo["users"].find({"deleted_at": None}, {"counts": 1}):
        actual = await mongo["stories"].count_documents(
            {
                "author_id": user["_id"],
                "visibility": {"$in": ["public", "private"]},
                "deleted_at": None,
            }
        )
        followers = await mongo["connections"].count_documents(
            {"followee_id": user["_id"], "status": "active"}
        )
        following = await mongo["connections"].count_documents(
            {"follower_id": user["_id"], "status": "active"}
        )
        counts = user.get("counts", {})

        if (
            counts.get("stories") != actual
            or counts.get("followers") != followers
            or counts.get("connections") != following
        ):
            await mongo["users"].update_one(
                {"_id": user["_id"]},
                {
                    "$set": {
                        "counts.stories": actual,
                        "counts.followers": followers,
                        "counts.connections": following,
                    }
                },
            )
            repaired["users"] += 1

    async for story in mongo["stories"].find({"deleted_at": None}, {"counts": 1}):
        likes = await mongo["reactions"].count_documents(
            {"target_kind": "story", "target_id": story["_id"]}
        )
        comments = await mongo["comments"].count_documents(
            {"story_id": story["_id"], "deleted_at": None}
        )
        counts = story.get("counts", {})

        if counts.get("likes") != likes or counts.get("comments") != comments:
            await mongo["stories"].update_one(
                {"_id": story["_id"]},
                {"$set": {"counts.likes": likes, "counts.comments": comments}},
            )
            repaired["stories"] += 1

    async for community in mongo["communities"].find({}, {"slug": 1, "counts": 1}):
        members = await mongo["community_members"].count_documents(
            {"community_slug": community["slug"]}
        )
        stories = await mongo["stories"].count_documents(
            {
                "community_slug": community["slug"],
                "visibility": "public",
                "deleted_at": None,
            }
        )
        counts = community.get("counts", {})

        if counts.get("members") != members or counts.get("stories") != stories:
            await mongo["communities"].update_one(
                {"_id": community["_id"]},
                {"$set": {"counts.members": members, "counts.stories": stories}},
            )
            repaired["communities"] += 1

    logger.info("counts_reconciled", count=sum(repaired.values()))
    return repaired
