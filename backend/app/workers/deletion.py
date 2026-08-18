from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.media.cleanup import drop_unused
from app.core.time import utc_now
from app.logging import get_logger
from app.ports.storage import StoragePort

logger = get_logger("story.workers.deletion")

PURGE_BATCH = 50


async def _ids(mongo: AsyncIOMotorDatabase, collection: str, query: dict[str, Any]) -> list[str]:
    return await mongo[collection].distinct("_id", query)


async def _give_back_comment_counts(
    mongo: AsyncIOMotorDatabase, user_id: str, mine: list[str]
) -> None:
    counts: dict[str, int] = {}
    async for comment in mongo["comments"].find(
        {"author_id": user_id, "story_id": {"$nin": mine}}, {"story_id": 1}
    ):
        counts[comment["story_id"]] = counts.get(comment["story_id"], 0) + 1

    for story_id, gone in counts.items():
        await mongo["stories"].update_one(
            {"_id": story_id}, {"$inc": {"counts.comments": -gone}}
        )


async def _give_back_likes(mongo: AsyncIOMotorDatabase, user_id: str, mine: list[str]) -> None:
    async for reaction in mongo["reactions"].find(
        {"user_id": user_id}, {"target_kind": 1, "target_id": 1}
    ):
        target_id = reaction["target_id"]
        if reaction["target_kind"] == "story":
            if target_id in mine:
                continue
            await mongo["stories"].update_one(
                {"_id": target_id},
                {"$inc": {"counts.likes": -1}, "$pull": {"likers": {"user_id": user_id}}},
            )
        else:
            await mongo["comments"].update_one(
                {"_id": target_id}, {"$inc": {"counts.likes": -1}}
            )


async def _let_go_of_people(mongo: AsyncIOMotorDatabase, user_id: str) -> None:
    async for tie in mongo["connections"].find(
        {"$or": [{"follower_id": user_id}, {"followee_id": user_id}]},
        {"follower_id": 1, "followee_id": 1, "status": 1},
    ):
        if tie.get("status") != "active":
            continue
        if tie["follower_id"] == user_id:
            await mongo["users"].update_one(
                {"_id": tie["followee_id"]}, {"$inc": {"counts.followers": -1}}
            )
        else:
            await mongo["users"].update_one(
                {"_id": tie["follower_id"]}, {"$inc": {"counts.connections": -1}}
            )

    await mongo["connections"].delete_many(
        {"$or": [{"follower_id": user_id}, {"followee_id": user_id}]}
    )

    async for seat in mongo["community_members"].find(
        {"user_id": user_id}, {"community_slug": 1}
    ):
        await mongo["communities"].update_one(
            {"slug": seat["community_slug"]}, {"$inc": {"counts.members": -1}}
        )
    await mongo["community_members"].delete_many({"user_id": user_id})


async def _close_the_chats(mongo: AsyncIOMotorDatabase, user_id: str) -> None:
    rooms = await _ids(mongo, "chat_conversations", {"participant_ids": user_id})
    if rooms:
        await mongo["chat_messages"].delete_many({"conversation_id": {"$in": rooms}})
        await mongo["chat_conversation_keys"].delete_many({"conversation_id": {"$in": rooms}})
        await mongo["chat_reads"].delete_many({"conversation_id": {"$in": rooms}})
        await mongo["chat_conversations"].delete_many({"_id": {"$in": rooms}})

    await mongo["chat_identities"].delete_many({"$or": [{"_id": user_id}, {"user_id": user_id}]})


async def erase_account(
    user_id: str, *, mongo: AsyncIOMotorDatabase, storage: StoragePort | None = None
) -> None:
    stories = await mongo["stories"].find({"author_id": user_id}, {"images": 1}).to_list(None)
    mine = [story["_id"] for story in stories]
    pictures = [url for story in stories for url in story.get("images", [])]

    await _give_back_comment_counts(mongo, user_id, mine)
    await _give_back_likes(mongo, user_id, mine)

    on_my_stories = await _ids(mongo, "comments", {"story_id": {"$in": mine}}) if mine else []
    my_comments = await _ids(mongo, "comments", {"author_id": user_id})
    gone_comments = list({*on_my_stories, *my_comments})

    await mongo["reactions"].delete_many(
        {
            "$or": [
                {"user_id": user_id},
                {"target_kind": "story", "target_id": {"$in": mine}},
                {"target_kind": "comment", "target_id": {"$in": gone_comments}},
            ]
        }
    )
    if gone_comments:
        await mongo["comments"].delete_many({"_id": {"$in": gone_comments}})
    if mine:
        await mongo["stories"].delete_many({"_id": {"$in": mine}})

    await _let_go_of_people(mongo, user_id)
    await _close_the_chats(mongo, user_id)

    await mongo["notifications"].delete_many(
        {"$or": [{"user_id": user_id}, {"actor_id": user_id}]}
    )
    await mongo["vault_items"].delete_many({"user_id": user_id})
    await mongo["user_passcodes"].delete_many({"user_id": user_id})
    await mongo["devices"].delete_many({"user_id": user_id})
    await mongo["push_tokens"].delete_many({"user_id": user_id})
    await mongo["user_keys"].delete_many({"$or": [{"_id": user_id}, {"user_id": user_id}]})
    await mongo["reports"].delete_many({"reporter_id": user_id})

    if pictures and storage is not None:
        await drop_unused(pictures, mongo=mongo, storage=storage)

    now = utc_now()
    user = await mongo["users"].find_one({"_id": user_id}, {"created_at": 1})
    if user is not None:
        await mongo["users"].replace_one(
            {"_id": user_id},
            {
                "username": f"deleted_{user_id}",
                "username_lower": f"deleted_{user_id}",
                "referral_code": f"gone_{user_id}",
                "status": "deleted",
                "deleted_at": now,
                "created_at": user.get("created_at", now),
                "updated_at": now,
            },
        )

    logger.info("account_erased", stories=len(mine), comments=len(gone_comments))


async def purge_deleted_accounts(
    mongo: AsyncIOMotorDatabase, *, storage: StoragePort | None = None
) -> int:
    due = (
        await mongo["users"]
        .find(
            {"status": "pending_deletion", "deletes_at": {"$lte": utc_now()}},
            {"_id": 1},
        )
        .limit(PURGE_BATCH)
        .to_list(length=PURGE_BATCH)
    )

    for user in due:
        await erase_account(user["_id"], mongo=mongo, storage=storage)

    if due:
        logger.info("accounts_purged", count=len(due))
    return len(due)
