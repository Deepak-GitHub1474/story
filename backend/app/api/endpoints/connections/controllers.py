from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.notifications.service import notify, withdraw
from app.core.errors import ErrorCode, api_error
from app.core.time import utc_now

USERS = "users"
CONNECTIONS = "connections"

LIST_LIMIT = 50
GRAPH_CAP = 500


async def _resolve(username: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[USERS].find_one(
        {"username_lower": username.lower(), "deleted_at": None},
        {"_id": 1, "username": 1, "display_name": 1, "avatar_seed": 1, "blocked": 1},
    )
    if user is None or user.get("blocked"):
        raise api_error(ErrorCode.USER_NOT_FOUND)
    return user


async def following_ids(user_id: str, mongo: AsyncIOMotorDatabase) -> list[str]:
    docs = (
        await mongo[CONNECTIONS]
        .find({"follower_id": user_id, "status": "active"}, {"followee_id": 1})
        .limit(GRAPH_CAP)
        .to_list(length=GRAPH_CAP)
    )
    return [doc["followee_id"] for doc in docs]


async def blocked_ids(user_id: str, mongo: AsyncIOMotorDatabase) -> list[str]:
    docs = (
        await mongo[CONNECTIONS]
        .find(
            {
                "status": "blocked",
                "$or": [{"follower_id": user_id}, {"followee_id": user_id}],
            },
            {"follower_id": 1, "followee_id": 1},
        )
        .limit(GRAPH_CAP)
        .to_list(length=GRAPH_CAP)
    )
    ids = set()
    for doc in docs:
        ids.add(doc["follower_id"])
        ids.add(doc["followee_id"])
    ids.discard(user_id)
    return list(ids)


async def is_following(follower_id: str, followee_id: str, mongo) -> bool:
    return (
        await mongo[CONNECTIONS].find_one(
            {"_id": f"{follower_id}:{followee_id}", "status": "active"}, {"_id": 1}
        )
    ) is not None


async def follow(
    username: str, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    target = await _resolve(username, mongo)
    if target["_id"] == claims.user_id:
        raise api_error(ErrorCode.SELF_FOLLOW)

    if await mongo[CONNECTIONS].find_one(
        {"_id": f"{target['_id']}:{claims.user_id}", "status": "blocked"}, {"_id": 1}
    ):
        raise api_error(ErrorCode.BLOCKED_BY_USER)

    result = await mongo[CONNECTIONS].update_one(
        {"_id": f"{claims.user_id}:{target['_id']}"},
        {
            "$setOnInsert": {
                "follower_id": claims.user_id,
                "followee_id": target["_id"],
                "status": "active",
                "created_at": utc_now(),
            }
        },
        upsert=True,
    )

    if result.upserted_id is not None:
        await mongo[USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.connections": 1}})
        await mongo[USERS].update_one({"_id": target["_id"]}, {"$inc": {"counts.followers": 1}})

        actor = await mongo[USERS].find_one(
            {"_id": claims.user_id},
            {"display_name": 1, "avatar_seed": 1, "username": 1},
        )
        await notify(
            mongo=mongo,
            user_id=target["_id"],
            actor_id=claims.user_id,
            actor_snapshot={
                "display_name": actor["display_name"],
                "avatar_seed": actor["avatar_seed"],
                "username": actor["username"],
            },
            kind="new_follower",
            target_kind="user",
            target_id=claims.user_id,
            body="started following you.",
            collapse=True,
            redis=redis,
)

    return {"is_following": True, "username": target["username"]}


async def unfollow(username: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    target = await _resolve(username, mongo)
    result = await mongo[CONNECTIONS].delete_one(
        {"_id": f"{claims.user_id}:{target['_id']}", "status": "active"}
    )

    if result.deleted_count:
        await mongo[USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.connections": -1}})
        await mongo[USERS].update_one({"_id": target["_id"]}, {"$inc": {"counts.followers": -1}})
        await withdraw(
            mongo=mongo,
            user_id=target["_id"],
            kind="new_follower",
            actor_id=claims.user_id,
            target_id=claims.user_id,
        )

    return {"is_following": False, "username": target["username"]}


async def block(username: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    target = await _resolve(username, mongo)
    if target["_id"] == claims.user_id:
        raise api_error(ErrorCode.SELF_FOLLOW)

    for follower, followee in (
        (claims.user_id, target["_id"]),
        (target["_id"], claims.user_id),
    ):
        removed = await mongo[CONNECTIONS].delete_one(
            {"_id": f"{follower}:{followee}", "status": "active"}
        )
        if removed.deleted_count:
            await mongo[USERS].update_one({"_id": follower}, {"$inc": {"counts.connections": -1}})
            await mongo[USERS].update_one({"_id": followee}, {"$inc": {"counts.followers": -1}})

    await mongo[CONNECTIONS].update_one(
        {"_id": f"{claims.user_id}:{target['_id']}:block"},
        {
            "$setOnInsert": {
                "follower_id": claims.user_id,
                "followee_id": target["_id"],
                "status": "blocked",
                "created_at": utc_now(),
            }
        },
        upsert=True,
    )
    return {"is_blocked": True, "username": target["username"]}


async def unblock(username: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    target = await _resolve(username, mongo)
    await mongo[CONNECTIONS].delete_one({"_id": f"{claims.user_id}:{target['_id']}:block"})
    return {"is_blocked": False, "username": target["username"]}


async def _people(ids: list[str], mongo: AsyncIOMotorDatabase) -> list[dict[str, Any]]:
    if not ids:
        return []
    docs = (
        await mongo[USERS]
        .find(
            {"_id": {"$in": ids}, "deleted_at": None, "blocked": {"$ne": True}},
            {"_id": 1, "username": 1, "display_name": 1, "avatar_seed": 1, "bio": 1},
        )
        .to_list(length=len(ids))
    )
    return [
        {
            "user_id": doc["_id"],
            "username": doc["username"],
            "display_name": doc["display_name"],
            "avatar_seed": doc["avatar_seed"],
            "bio": doc.get("bio"),
        }
        for doc in docs
    ]


async def list_following(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[CONNECTIONS]
        .find({"follower_id": claims.user_id, "status": "active"}, {"followee_id": 1})
        .sort("_id", -1)
        .limit(LIST_LIMIT)
        .to_list(length=LIST_LIMIT)
    )
    return {"items": await _people([doc["followee_id"] for doc in docs], mongo)}


async def list_followers(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[CONNECTIONS]
        .find({"followee_id": claims.user_id, "status": "active"}, {"follower_id": 1})
        .sort("_id", -1)
        .limit(LIST_LIMIT)
        .to_list(length=LIST_LIMIT)
    )
    return {"items": await _people([doc["follower_id"] for doc in docs], mongo)}


async def list_blocked(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[CONNECTIONS]
        .find({"follower_id": claims.user_id, "status": "blocked"}, {"followee_id": 1})
        .limit(LIST_LIMIT)
        .to_list(length=LIST_LIMIT)
    )
    return {"items": await _people([doc["followee_id"] for doc in docs], mongo)}
