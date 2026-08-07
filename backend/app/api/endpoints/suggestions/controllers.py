from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.connections import controllers as connection_controllers

COMMUNITIES = "communities"
COMMUNITY_MEMBERS = "community_members"
INTERESTS = "interests"
STORIES = "stories"
USERS = "users"

COMMUNITY_LIMIT = 8
PEOPLE_LIMIT = 8
SCAN_LIMIT = 200


def _community(doc: dict[str, Any]) -> dict[str, Any]:
    return {
        "slug": doc["slug"],
        "name": doc.get("name", doc["slug"]),
        "description": doc.get("description"),
        "category_id": doc.get("category_id"),
        "icon": doc.get("icon"),
        "is_member": False,
        "counts": {
            "members": (doc.get("counts") or {}).get("members", 0),
            "stories": (doc.get("counts") or {}).get("stories", 0),
        },
    }


def _person(doc: dict[str, Any], reason: str) -> dict[str, Any]:
    return {
        "user_id": doc["_id"],
        "username": doc.get("username"),
        "display_name": doc.get("display_name", "Someone"),
        "avatar_seed": doc.get("avatar_seed", ""),
        "reason": reason,
    }


async def _joined_slugs(user_id: str, mongo: AsyncIOMotorDatabase) -> list[str]:
    return await mongo[COMMUNITY_MEMBERS].distinct("community_slug", {"user_id": user_id})


async def _liked_categories(user_id: str, mongo: AsyncIOMotorDatabase) -> list[str]:
    user = await mongo[USERS].find_one({"_id": user_id}, {"interests": 1})
    slugs = (user or {}).get("interests") or []
    if not slugs:
        return []

    rows = await mongo[INTERESTS].find(
        {"_id": {"$in": slugs}}, {"category_id": 1}
    ).to_list(length=len(slugs))
    return list(dict.fromkeys(row.get("category_id") for row in rows if row.get("category_id")))


async def _communities_for(
    user_id: str, mongo: AsyncIOMotorDatabase
) -> list[dict[str, Any]]:
    joined = await _joined_slugs(user_id, mongo)
    categories = await _liked_categories(user_id, mongo)

    query: dict[str, Any] = {"status": "active", "slug": {"$nin": joined}}
    docs = (
        await mongo[COMMUNITIES]
        .find(query)
        .sort([("category_order", 1), ("counts.members", -1)])
        .limit(SCAN_LIMIT)
        .to_list(length=SCAN_LIMIT)
    )

    liked = [doc for doc in docs if doc.get("category_id") in categories]
    rest = [doc for doc in docs if doc.get("category_id") not in categories]
    return [_community(doc) for doc in (liked + rest)[:COMMUNITY_LIMIT]]


async def _people_for(user_id: str, mongo: AsyncIOMotorDatabase) -> list[dict[str, Any]]:
    joined = await _joined_slugs(user_id, mongo)
    following = await connection_controllers.following_ids(user_id, mongo)
    blocked = await connection_controllers.blocked_ids(user_id, mongo)
    skip = {user_id, *following, *blocked}

    scored: dict[str, str] = {}

    if joined:
        neighbours = await mongo[STORIES].distinct(
            "author_id",
            {
                "community_slug": {"$in": joined},
                "visibility": "public",
                "deleted_at": None,
            },
        )
        for author_id in neighbours:
            if author_id not in skip:
                scored[author_id] = "In a room you joined"

    if following and len(scored) < PEOPLE_LIMIT:
        onwards = await mongo["connections"].distinct(
            "followee_id", {"follower_id": {"$in": following}, "kind": "follow"}
        )
        for candidate in onwards:
            if candidate not in skip and candidate not in scored:
                scored[candidate] = "Followed by people you follow"

    if not scored:
        return []

    ids = list(scored)[:PEOPLE_LIMIT]
    docs = await mongo[USERS].find(
        {"_id": {"$in": ids}, "status": "active"},
        {"username": 1, "display_name": 1, "avatar_seed": 1},
    ).to_list(length=len(ids))

    return [_person(doc, scored[doc["_id"]]) for doc in docs]


async def suggestions(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    return {
        "communities": await _communities_for(claims.user_id, mongo),
        "people": await _people_for(claims.user_id, mongo),
    }
