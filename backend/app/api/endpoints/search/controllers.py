import re
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.connections import controllers as connection_controllers
from app.api.endpoints.stories.utils import serialize_story

RESULT_LIMIT = 20

USERS = "users"
COMMUNITIES = "communities"
STORIES = "stories"

USER_PROJECTION = {"_id": 1, "username": 1, "display_name": 1, "avatar_seed": 1, "bio": 1}
COMMUNITY_PROJECTION = {
    "slug": 1,
    "name": 1,
    "description": 1,
    "category_id": 1,
    "counts": 1,
}
STORY_PROJECTION = {
    "_id": 1,
    "author_id": 1,
    "author_snapshot": 1,
    "community": 1,
    "title": 1,
    "excerpt": 1,
    "visibility": 1,
    "slug": 1,
    "counts": 1,
    "reading_minutes": 1,
    "published_at": 1,
    "created_at": 1,
    "updated_at": 1,
}


def safe_pattern(query: str) -> dict[str, str]:
    return {"$regex": re.escape(query.strip()), "$options": "i"}


async def search(*, query: str, kind: str, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    pattern = safe_pattern(query)
    wants = {"all", kind}

    users: list[dict[str, Any]] = []
    communities: list[dict[str, Any]] = []
    stories: list[dict[str, Any]] = []

    if "users" in wants or "all" in wants:
        excluded = set(await connection_controllers.blocked_ids(claims.user_id, mongo))
        excluded.add(claims.user_id)
        docs = (
            await mongo[USERS]
            .find(
                {
                    "_id": {"$nin": list(excluded)},
                    "deleted_at": None,
                    "blocked": {"$ne": True},
                    "$or": [{"username": pattern}, {"display_name": pattern}],
                },
                USER_PROJECTION,
            )
            .limit(RESULT_LIMIT)
            .to_list(length=RESULT_LIMIT)
        )
        users = [
            {
                "user_id": doc["_id"],
                "username": doc["username"],
                "display_name": doc["display_name"],
                "avatar_seed": doc["avatar_seed"],
                "bio": doc.get("bio"),
            }
            for doc in docs
        ]

    if "communities" in wants or "all" in wants:
        docs = (
            await mongo[COMMUNITIES]
            .find(
                {
                    "status": "active",
                    "$or": [{"name": pattern}, {"slug": pattern}, {"description": pattern}],
                },
                COMMUNITY_PROJECTION,
            )
            .sort("counts.members", -1)
            .limit(RESULT_LIMIT)
            .to_list(length=RESULT_LIMIT)
        )
        communities = [
            {
                "slug": doc["slug"],
                "name": doc["name"],
                "description": doc.get("description", ""),
                "category_id": doc.get("category_id"),
                "counts": doc.get("counts", {}),
                "is_member": False,
            }
            for doc in docs
        ]

    if "stories" in wants or "all" in wants:
        blocked = await connection_controllers.blocked_ids(claims.user_id, mongo)
        selector: dict[str, Any] = {
            "visibility": "public",
            "deleted_at": None,
            "moderation.state": "allowed",
            "$or": [{"title": pattern}, {"body": pattern}],
        }
        if blocked:
            selector["author_id"] = {"$nin": blocked}

        docs = (
            await mongo[STORIES]
            .find(selector, STORY_PROJECTION)
            .sort("_id", -1)
            .limit(RESULT_LIMIT)
            .to_list(length=RESULT_LIMIT)
        )
        stories = [serialize_story(doc, include_body=False) for doc in docs]

    return {"users": users, "communities": communities, "stories": stories}
