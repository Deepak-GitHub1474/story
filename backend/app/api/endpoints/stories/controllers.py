from datetime import timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.stories import constants as c
from app.api.endpoints.stories.models import (
    CreateCommentRequest,
    CreateStoryRequest,
    PublishStoryRequest,
    UpdateStoryRequest,
)
from app.api.endpoints.stories.utils import (
    build_excerpt,
    new_slug,
    reading_minutes,
    serialize_comment,
    serialize_story,
)
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.time import utc_now


def _to_minute(value):
    return value.replace(second=0, microsecond=0)


async def _author_snapshot(user_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[c.USERS].find_one(
        {"_id": user_id}, {"display_name": 1, "avatar_seed": 1, "username": 1}
    )
    if user is None:
        raise api_error(ErrorCode.USER_NOT_FOUND)
    return {
        "display_name": user["display_name"],
        "avatar_seed": user["avatar_seed"],
        "username": user["username"],
    }


async def _owned_story(story_id: str, user_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    story = await mongo[c.STORIES].find_one(
        {"_id": story_id, "author_id": user_id, "deleted_at": None}
    )
    if story is None:
        raise api_error(ErrorCode.STORY_NOT_FOUND)
    return story


async def _readable_story(
    story_id: str, user_id: str, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    story = await mongo[c.STORIES].find_one({"_id": story_id, "deleted_at": None})
    if story is None:
        raise api_error(ErrorCode.STORY_NOT_FOUND)
    if story["author_id"] != user_id and story["visibility"] != "public":
        raise api_error(ErrorCode.STORY_NOT_FOUND)
    return story


async def _has_liked(user_id: str, target_kind: str, target_id: str, mongo) -> bool:
    return (
        await mongo[c.REACTIONS].find_one(
            {"_id": f"{user_id}:{target_kind}:{target_id}"}, {"_id": 1}
        )
    ) is not None


async def create_story(
    body: CreateStoryRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    now = utc_now()
    story = {
        "_id": new_id("sto"),
        "author_id": claims.user_id,
        "author_snapshot": await _author_snapshot(claims.user_id, mongo),
        "title": body.title or None,
        "body": body.body,
        "excerpt": build_excerpt(body.body),
        "reading_minutes": reading_minutes(body.body),
        "visibility": "draft",
        "community_id": None,
        "slug": None,
        "media": [],
        "counts": {"likes": 0, "comments": 0, "shares": 0, "views": 0},
        "moderation": {"state": "unreviewed", "verdict": None, "rule": None},
        "published_at": None,
        "edited_at": None,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }
    await mongo[c.STORIES].insert_one(story)
    return {"story": serialize_story(story, include_body=True)}


async def update_story(
    story_id: str, body: UpdateStoryRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)

    if story["visibility"] != "draft" and story.get("published_at"):
        deadline = story["published_at"] + timedelta(hours=c.EDIT_WINDOW_HOURS)
        if utc_now() > deadline:
            raise api_error(ErrorCode.STORY_NOT_EDITABLE)

    update: dict[str, Any] = {"updated_at": utc_now()}
    if body.title is not None:
        update["title"] = body.title or None
    if body.body is not None:
        update["body"] = body.body
        update["excerpt"] = build_excerpt(body.body)
        update["reading_minutes"] = reading_minutes(body.body)
    if story["visibility"] != "draft":
        update["edited_at"] = utc_now()

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": update})
    story.update(update)
    return {"story": serialize_story(story, include_body=True)}


async def publish_story(
    story_id: str, body: PublishStoryRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)
    now = utc_now()

    update: dict[str, Any] = {
        "visibility": body.visibility,
        "updated_at": now,
        "moderation.state": "allowed",
    }
    if story.get("published_at") is None:
        update["published_at"] = _to_minute(now)
    if body.visibility == "public" and not story.get("slug"):
        update["slug"] = new_slug()

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": update})

    if story["visibility"] == "draft":
        await mongo[c.USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.stories": 1}})

    story.update(update)
    return {"story": serialize_story(story, include_body=True)}


async def unpublish_story(story_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)

    if story["visibility"] != "draft":
        await mongo[c.USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.stories": -1}})

    update = {"visibility": "draft", "updated_at": utc_now()}
    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": update})
    story.update(update)
    return {"story": serialize_story(story, include_body=True)}


async def delete_story(story_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)

    if story["visibility"] != "draft":
        await mongo[c.USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.stories": -1}})

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": {"deleted_at": utc_now()}})
    return {"deleted": True, "story_id": story_id}


async def get_story(story_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    story = await _readable_story(story_id, claims.user_id, mongo)
    liked = await _has_liked(claims.user_id, "story", story_id, mongo)
    return {"story": serialize_story(story, include_body=True, is_liked=liked)}


async def list_mine(
    *, claims, mongo: AsyncIOMotorDatabase, visibility: str | None, limit: int, cursor: str | None
) -> dict[str, Any]:
    query: dict[str, Any] = {"author_id": claims.user_id, "deleted_at": None}
    if visibility:
        query["visibility"] = visibility
    return await _paginate(query, mongo=mongo, limit=limit, cursor=cursor)


async def list_feed(
    *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    query = {"visibility": "public", "deleted_at": None, "moderation.state": "allowed"}
    return await _paginate(query, mongo=mongo, limit=limit, cursor=cursor)


async def list_user_stories(
    username: str, *, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    author = await mongo[c.USERS].find_one(
        {"username_lower": username.lower(), "deleted_at": None}, {"_id": 1, "blocked": 1}
    )
    if author is None or author.get("blocked"):
        raise api_error(ErrorCode.USER_NOT_FOUND)

    query = {
        "author_id": author["_id"],
        "visibility": "public",
        "deleted_at": None,
        "moderation.state": "allowed",
    }
    return await _paginate(query, mongo=mongo, limit=limit, cursor=cursor)


async def _paginate(
    query: dict[str, Any], *, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    limit = max(1, min(limit, c.FEED_MAX_LIMIT))
    if cursor:
        query = {**query, "_id": {"$lt": cursor}}

    docs = (
        await mongo[c.STORIES]
        .find(query, c.FEED_PROJECTION)
        .sort("_id", -1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )

    has_more = len(docs) > limit
    page = docs[:limit]
    return {
        "items": [serialize_story(doc, include_body=False) for doc in page],
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


async def set_like(
    story_id: str, *, liked: bool, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    story = await _readable_story(story_id, claims.user_id, mongo)
    reaction_id = f"{claims.user_id}:story:{story_id}"

    if liked:
        result = await mongo[c.REACTIONS].update_one(
            {"_id": reaction_id},
            {
                "$setOnInsert": {
                    "user_id": claims.user_id,
                    "target_kind": "story",
                    "target_id": story_id,
                    "kind": "like",
                    "created_at": utc_now(),
                }
            },
            upsert=True,
        )
        delta = 1 if result.upserted_id is not None else 0
    else:
        result = await mongo[c.REACTIONS].delete_one({"_id": reaction_id})
        delta = -1 if result.deleted_count else 0

    if delta:
        await mongo[c.STORIES].update_one({"_id": story_id}, {"$inc": {"counts.likes": delta}})

    likes = max(0, story.get("counts", {}).get("likes", 0) + delta)
    return {"likes": likes, "is_liked": liked}


async def create_comment(
    story_id: str, body: CreateCommentRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    await _readable_story(story_id, claims.user_id, mongo)

    if body.parent_id:
        parent = await mongo[c.COMMENTS].find_one(
            {"_id": body.parent_id, "story_id": story_id, "deleted_at": None}
        )
        if parent is None:
            raise api_error(ErrorCode.COMMENT_NOT_FOUND)
        if parent.get("parent_id"):
            raise api_error(ErrorCode.NESTING_TOO_DEEP)

    now = utc_now()
    comment = {
        "_id": new_id("cmt"),
        "story_id": story_id,
        "author_id": claims.user_id,
        "author_snapshot": await _author_snapshot(claims.user_id, mongo),
        "parent_id": body.parent_id,
        "body": body.body,
        "counts": {"likes": 0, "replies": 0},
        "is_tombstone": False,
        "moderation": {"state": "allowed", "verdict": None, "rule": None},
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }
    await mongo[c.COMMENTS].insert_one(comment)
    await mongo[c.STORIES].update_one({"_id": story_id}, {"$inc": {"counts.comments": 1}})
    if body.parent_id:
        await mongo[c.COMMENTS].update_one({"_id": body.parent_id}, {"$inc": {"counts.replies": 1}})

    return {"comment": serialize_comment(comment)}


async def list_comments(
    story_id: str, *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    await _readable_story(story_id, claims.user_id, mongo)

    limit = max(1, min(limit, c.FEED_MAX_LIMIT))
    query: dict[str, Any] = {"story_id": story_id, "deleted_at": None}
    if cursor:
        query["_id"] = {"$gt": cursor}

    docs = (
        await mongo[c.COMMENTS]
        .find(query)
        .sort("_id", 1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )
    has_more = len(docs) > limit
    page = docs[:limit]

    liked_ids = set()
    if page:
        ids = [f"{claims.user_id}:comment:{doc['_id']}" for doc in page]
        async for reaction in mongo[c.REACTIONS].find({"_id": {"$in": ids}}, {"target_id": 1}):
            liked_ids.add(reaction["target_id"])

    return {
        "items": [serialize_comment(doc, is_liked=doc["_id"] in liked_ids) for doc in page],
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


async def delete_comment(comment_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    comment = await mongo[c.COMMENTS].find_one({"_id": comment_id, "deleted_at": None})
    if comment is None:
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)

    story = await mongo[c.STORIES].find_one({"_id": comment["story_id"]}, {"author_id": 1})
    is_owner = comment["author_id"] == claims.user_id
    is_story_author = story is not None and story["author_id"] == claims.user_id
    if not (is_owner or is_story_author):
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)

    await mongo[c.COMMENTS].update_one({"_id": comment_id}, {"$set": {"deleted_at": utc_now()}})
    await mongo[c.STORIES].update_one(
        {"_id": comment["story_id"]}, {"$inc": {"counts.comments": -1}}
    )
    return {"deleted": True, "comment_id": comment_id}


async def set_comment_like(
    comment_id: str, *, liked: bool, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    comment = await mongo[c.COMMENTS].find_one({"_id": comment_id, "deleted_at": None})
    if comment is None:
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)

    reaction_id = f"{claims.user_id}:comment:{comment_id}"
    if liked:
        result = await mongo[c.REACTIONS].update_one(
            {"_id": reaction_id},
            {
                "$setOnInsert": {
                    "user_id": claims.user_id,
                    "target_kind": "comment",
                    "target_id": comment_id,
                    "kind": "like",
                    "created_at": utc_now(),
                }
            },
            upsert=True,
        )
        delta = 1 if result.upserted_id is not None else 0
    else:
        result = await mongo[c.REACTIONS].delete_one({"_id": reaction_id})
        delta = -1 if result.deleted_count else 0

    if delta:
        await mongo[c.COMMENTS].update_one({"_id": comment_id}, {"$inc": {"counts.likes": delta}})

    likes = max(0, comment.get("counts", {}).get("likes", 0) + delta)
    return {"likes": likes, "is_liked": liked}
