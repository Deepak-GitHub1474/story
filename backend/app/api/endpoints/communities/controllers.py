from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.errors import ErrorCode, api_error
from app.core.time import utc_now

COMMUNITIES = "communities"
MEMBERS = "community_members"
CATEGORIES = "community_categories"

LIST_LIMIT = 60
MEMBER_CAP = 200

PROJECTION = {
    "_id": 1,
    "slug": 1,
    "name": 1,
    "description": 1,
    "category_id": 1,
    "icon": 1,
    "accent_token": 1,
    "counts": 1,
    "member_directory": 1,
}


def serialize(doc: dict[str, Any], *, is_member: bool = False) -> dict[str, Any]:
    return {
        "slug": doc["slug"],
        "name": doc["name"],
        "description": doc.get("description", ""),
        "category_id": doc.get("category_id"),
        "icon": doc.get("icon"),
        "accent_token": doc.get("accent_token", "accent"),
        "counts": doc.get("counts", {"members": 0, "stories": 0}),
        "is_member": is_member,
    }


async def joined_slugs(user_id: str, mongo: AsyncIOMotorDatabase) -> list[str]:
    docs = (
        await mongo[MEMBERS]
        .find({"user_id": user_id}, {"community_slug": 1})
        .limit(MEMBER_CAP)
        .to_list(length=MEMBER_CAP)
    )
    return [doc["community_slug"] for doc in docs]


async def _require(slug: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    community = await mongo[COMMUNITIES].find_one(
        {"slug": slug, "status": {"$ne": "deleted"}}, PROJECTION
    )
    if community is None:
        raise api_error(ErrorCode.COMMUNITY_NOT_FOUND)
    return community


async def is_member(user_id: str, slug: str, mongo: AsyncIOMotorDatabase) -> bool:
    return (await mongo[MEMBERS].find_one({"_id": f"{user_id}:{slug}"}, {"_id": 1})) is not None


async def list_communities(
    *, claims, mongo: AsyncIOMotorDatabase, category: str | None, query: str | None
) -> dict[str, Any]:
    selector: dict[str, Any] = {"status": "active"}
    if category:
        selector["category_id"] = category
    if query:
        selector["name"] = {"$regex": query, "$options": "i"}

    docs = (
        await mongo[COMMUNITIES]
        .find(selector, PROJECTION)
        .sort([("category_order", 1), ("counts.members", -1), ("name", 1)])
        .limit(LIST_LIMIT)
        .to_list(length=LIST_LIMIT)
    )
    joined = set(await joined_slugs(claims.user_id, mongo))
    return {"items": [serialize(doc, is_member=doc["slug"] in joined) for doc in docs]}


async def my_communities(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    slugs = await joined_slugs(claims.user_id, mongo)
    if not slugs:
        return {"items": []}
    docs = (
        await mongo[COMMUNITIES]
        .find({"slug": {"$in": slugs}, "status": {"$ne": "deleted"}}, PROJECTION)
        .to_list(length=len(slugs))
    )
    return {"items": [serialize(doc, is_member=True) for doc in docs]}


async def community_detail(slug: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    community = await _require(slug, mongo)
    member = await is_member(claims.user_id, slug, mongo)
    return {"community": serialize(community, is_member=member)}


async def join(slug: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    community = await _require(slug, mongo)
    result = await mongo[MEMBERS].update_one(
        {"_id": f"{claims.user_id}:{slug}"},
        {
            "$setOnInsert": {
                "user_id": claims.user_id,
                "community_slug": slug,
                "joined_at": utc_now(),
                "notifications_enabled": True,
            }
        },
        upsert=True,
    )
    if result.upserted_id is not None:
        await mongo[COMMUNITIES].update_one({"slug": slug}, {"$inc": {"counts.members": 1}})
        await mongo["users"].update_one(
            {"_id": claims.user_id}, {"$inc": {"counts.communities": 1}}
        )
        community["counts"]["members"] = community.get("counts", {}).get("members", 0) + 1

    return {"community": serialize(community, is_member=True)}


async def leave(slug: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    community = await _require(slug, mongo)
    result = await mongo[MEMBERS].delete_one({"_id": f"{claims.user_id}:{slug}"})
    if result.deleted_count:
        await mongo[COMMUNITIES].update_one({"slug": slug}, {"$inc": {"counts.members": -1}})
        await mongo["users"].update_one(
            {"_id": claims.user_id}, {"$inc": {"counts.communities": -1}}
        )
        community["counts"]["members"] = max(0, community.get("counts", {}).get("members", 0) - 1)

    return {"community": serialize(community, is_member=False)}


async def list_categories(*, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[CATEGORIES].find({"status": "active"}).sort("sort_order", 1).to_list(length=100)
    )
    return {
        "items": [
            {
                "slug": doc["_id"],
                "name": doc["name"],
                "tone": doc["tone"],
                "description": doc.get("description", ""),
                "icon": doc.get("icon"),
            }
            for doc in docs
        ]
    }
