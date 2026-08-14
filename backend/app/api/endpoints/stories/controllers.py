from dataclasses import replace
from datetime import timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.adapters.ai_gemini import ModerationUnavailable
from app.api.endpoints.communities import controllers as community_controllers
from app.api.endpoints.connections import controllers as connection_controllers
from app.api.endpoints.media.cleanup import drop_unused
from app.api.endpoints.notifications.service import notify, preview, withdraw
from app.api.endpoints.stories import constants as c
from app.api.endpoints.stories.models import (
    CreateCommentRequest,
    CreateStoryRequest,
    PublishStoryRequest,
    UpdateCommentRequest,
    UpdateStoryRequest,
)
from app.api.endpoints.stories.utils import (
    build_excerpt,
    new_slug,
    reading_minutes,
    serialize_comment,
    serialize_story,
)
from app.core.accounts import GONE_STATUSES
from app.core.care import sounds_at_risk
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.time import from_wire, to_storage, to_wire, utc_now
from app.ports.ai import ALLOWED, AIPort, StoryReview
from app.ports.storage import StoragePort


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
    shared_id = None

    if body.shared_story_id is not None:
        source = await mongo[c.STORIES].find_one(
            {"_id": body.shared_story_id, "deleted_at": None}
        )
        if source is None:
            raise api_error(ErrorCode.STORY_NOT_FOUND, field="shared_story_id")
        if source["visibility"] != "public":
            raise api_error(ErrorCode.STORY_NOT_SHAREABLE, field="shared_story_id")

        shared_id = source.get("shared_story_id") or source["_id"]
        await mongo[c.STORIES].update_one(
            {"_id": shared_id}, {"$inc": {"counts.shares": 1}}
        )

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
        "shared_story_id": shared_id,
        "images": body.images,
        "image_ratio": body.image_ratio,
        "image_fit": body.image_fit,
        "counts": {"likes": 0, "comments": 0, "shares": 0, "views": 0},
        "moderation": {"state": "unreviewed", "verdict": None, "rule": None},
        "published_at": None,
        "edited_at": None,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }
    await mongo[c.STORIES].insert_one(story)
    return {
        "story": await _with_shared(
            serialize_story(story, include_body=True), story, mongo
        )
    }


def _shared_payload(source: dict[str, Any]) -> dict[str, Any]:
    snapshot = source.get("author_snapshot") or {}
    return {
        "story_id": source["_id"],
        "title": source.get("title"),
        "excerpt": source.get("excerpt", ""),
        "slug": source.get("slug"),
        "author": {
            "user_id": source.get("author_id"),
            "username": snapshot.get("username", ""),
            "display_name": snapshot.get("display_name", "Someone"),
            "avatar_seed": snapshot.get("avatar_seed", ""),
        },
    }


async def _with_shared(payload, story, mongo) -> dict[str, Any]:
    shared_id = story.get("shared_story_id")
    if shared_id is None:
        return payload

    source = await mongo[c.STORIES].find_one({"_id": shared_id, "deleted_at": None})
    if source is None:
        return payload

    payload["shared"] = _shared_payload(source)
    return payload


async def _attach_shared(payloads, docs, mongo) -> list[dict[str, Any]]:
    wanted = {doc["shared_story_id"] for doc in docs if doc.get("shared_story_id")}
    if not wanted:
        return payloads

    sources = (
        await mongo[c.STORIES]
        .find({"_id": {"$in": list(wanted)}, "deleted_at": None}, c.FEED_PROJECTION)
        .to_list(length=len(wanted))
    )
    by_id = {source["_id"]: source for source in sources}

    for payload, doc in zip(payloads, docs, strict=True):
        source = by_id.get(doc.get("shared_story_id"))
        if source is not None:
            payload["shared"] = _shared_payload(source)
    return payloads


async def update_story(
    story_id: str,
    body: UpdateStoryRequest,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    storage: StoragePort,
) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)

    update: dict[str, Any] = {"updated_at": utc_now()}
    if body.title is not None:
        update["title"] = body.title or None
    if body.body is not None:
        update["body"] = body.body
        update["excerpt"] = build_excerpt(body.body)
        update["reading_minutes"] = reading_minutes(body.body)
    if body.images is not None:
        update["images"] = body.images
    if body.image_ratio is not None:
        update["image_ratio"] = body.image_ratio
    if body.image_fit is not None:
        update["image_fit"] = body.image_fit
    if story["visibility"] != "draft":
        update["edited_at"] = utc_now()

    dropped = [
        url for url in story.get("images", []) if url not in (body.images or [])
    ] if body.images is not None else []

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": update})
    if dropped:
        await drop_unused(dropped, mongo=mongo, storage=storage)

    story.update(update)
    return {"story": serialize_story(story, include_body=True)}


async def publish_story(
    story_id: str,
    body: PublishStoryRequest,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    ai: AIPort | None = None,
    redis=None,
) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)
    now = utc_now()

    review = await _review(story, body, ai=ai, mongo=mongo)

    update: dict[str, Any] = {
        "visibility": body.visibility,
        "updated_at": now,
        "moderation.state": "allowed",
    }

    if body.visibility == "scheduled":
        if body.scheduled_for is None:
            raise api_error(ErrorCode.SCHEDULE_REQUIRED, field="scheduled_for")
        scheduled_for = to_storage(body.scheduled_for)
        if scheduled_for <= now:
            raise api_error(ErrorCode.SCHEDULE_IN_PAST, field="scheduled_for")
        update["scheduled_for"] = scheduled_for
    else:
        update["scheduled_for"] = None
        if story.get("published_at") is None:
            update["published_at"] = _to_minute(now)

    if body.visibility in ("public", "scheduled") and not story.get("slug"):
        update["slug"] = new_slug()

    if body.community_slug:
        community = await mongo["communities"].find_one(
            {"slug": body.community_slug, "status": "active"},
            {"slug": 1, "name": 1, "category_id": 1},
        )
        if community is None:
            raise api_error(ErrorCode.COMMUNITY_NOT_FOUND)
        if not await community_controllers.is_member(claims.user_id, body.community_slug, mongo):
            raise api_error(ErrorCode.NOT_A_MEMBER)
        update["community_slug"] = body.community_slug
        update["community"] = {
            "slug": community["slug"],
            "name": community["name"],
            "category_id": community.get("category_id"),
        }

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": update})

    if story["visibility"] == "draft" and body.visibility != "scheduled":
        await mongo[c.USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.stories": 1}})
        if body.community_slug:
            await mongo["communities"].update_one(
                {"slug": body.community_slug}, {"$inc": {"counts.stories": 1}}
            )
            await _notify_community(
                body.community_slug,
                story_id=story_id,
                claims=claims,
                mongo=mongo,
                community_name=update["community"]["name"],
                redis=redis,
            )

    story.update(update)
    return {
        "story": serialize_story(story, include_body=True),
        "suggested_community": review.suggested_community,
        "needs_care": review.needs_care or sounds_at_risk(story.get("body") or ""),
    }


async def _review(
    story,
    body: PublishStoryRequest,
    *,
    ai: AIPort | None,
    mongo: AsyncIOMotorDatabase,
) -> StoryReview:
    if ai is None or body.visibility == "private":
        return ALLOWED

    if story.get("shared_story_id") is not None:
        return ALLOWED

    try:
        review = await ai.review_story(
            title=story.get("title"),
            body=story.get("body") or "",
            community=body.community_slug,
            rooms=await _room_slugs(mongo),
        )
    except ModerationUnavailable:
        raise api_error(ErrorCode.MODERATION_UNAVAILABLE) from None

    if not review.is_allowed:
        raise api_error(
            ErrorCode.MODERATION_BLOCKED,
            message=review.reason,
            extra={"rule": review.rule},
        )

    if review.is_exposing and not body.exposure_ack:
        raise api_error(
            ErrorCode.EXPOSURE_ACK_REQUIRED,
            extra={"exposes": review.exposes},
        )

    return replace(
        review,
        suggested_community=await _real_room(
            review.suggested_community, body.community_slug, mongo
        ),
    )


async def _room_slugs(mongo: AsyncIOMotorDatabase) -> list[str]:
    return await mongo["communities"].distinct("slug", {"status": "active"})


async def _real_room(
    suggested: str | None, chosen: str | None, mongo: AsyncIOMotorDatabase
) -> str | None:
    if suggested is None or suggested == chosen:
        return None

    room = await mongo["communities"].find_one(
        {"slug": suggested, "status": "active"}, {"_id": 1}
    )
    return suggested if room else None


async def _notify_community(
    slug: str,
    *,
    story_id: str,
    claims,
    mongo: AsyncIOMotorDatabase,
    community_name: str,
    redis=None,
) -> None:
    snapshot = await _author_snapshot(claims.user_id, mongo)
    members = (
        await mongo["community_members"]
        .find({"community_slug": slug, "user_id": {"$ne": claims.user_id}}, {"user_id": 1})
        .limit(c.COMMUNITY_FANOUT_CAP)
        .to_list(length=c.COMMUNITY_FANOUT_CAP)
    )
    for member in members:
        await notify(
            mongo=mongo,
            user_id=member["user_id"],
            actor_id=claims.user_id,
            actor_snapshot=snapshot,
            kind="community_story",
            target_kind="story",
            target_id=story_id,
            body=f"posted in {community_name}.",
            redis=redis,
)


async def unpublish_story(story_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)

    if story["visibility"] != "draft":
        await mongo[c.USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.stories": -1}})

    update = {"visibility": "draft", "updated_at": utc_now()}
    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": update})
    story.update(update)
    return {"story": serialize_story(story, include_body=True)}


async def delete_story(
    story_id: str, *, claims, mongo: AsyncIOMotorDatabase, storage: StoragePort
) -> dict[str, Any]:
    story = await _owned_story(story_id, claims.user_id, mongo)

    if story["visibility"] != "draft":
        await mongo[c.USERS].update_one({"_id": claims.user_id}, {"$inc": {"counts.stories": -1}})

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$set": {"deleted_at": utc_now()}})
    await drop_unused(story.get("images", []), mongo=mongo, storage=storage)
    return {"deleted": True, "story_id": story_id}


async def share_story(
    story_id: str, *, claims, mongo: AsyncIOMotorDatabase, base_url: str
) -> dict[str, Any]:
    story = await _readable_story(story_id, claims.user_id, mongo)
    if story["visibility"] != "public" or not story.get("slug"):
        raise api_error(ErrorCode.STORY_NOT_SHAREABLE)

    await mongo[c.STORIES].update_one({"_id": story_id}, {"$inc": {"counts.shares": 1}})
    shares = story.get("counts", {}).get("shares", 0) + 1

    return {
        "slug": story["slug"],
        "url": f"{base_url.rstrip('/')}/s/{story['slug']}",
        "shares": shares,
    }


async def get_story(story_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    story = await _readable_story(story_id, claims.user_id, mongo)
    liked = await _has_liked(claims.user_id, "story", story_id, mongo)
    return {
        "story": await _with_shared(
            serialize_story(story, include_body=True, is_liked=liked), story, mongo
        )
    }


async def list_mine(
    *, claims, mongo: AsyncIOMotorDatabase, visibility: str | None, limit: int, cursor: str | None
) -> dict[str, Any]:
    query: dict[str, Any] = {"author_id": claims.user_id, "deleted_at": None}
    if visibility:
        query["visibility"] = visibility
    return await _paginate(
        query, mongo=mongo, limit=limit, cursor=cursor, viewer_id=claims.user_id
    )


async def list_feed(
    *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    limit = max(1, min(limit, c.FEED_MAX_LIMIT))

    following = await connection_controllers.following_ids(claims.user_id, mongo)
    joined = await community_controllers.joined_slugs(claims.user_id, mongo)
    blocked = await connection_controllers.blocked_ids(claims.user_id, mongo)

    personal_clauses: list[dict[str, Any]] = []
    if following:
        personal_clauses.append({"author_id": {"$in": following}})
    if joined:
        personal_clauses.append({"community_slug": {"$in": joined}})

    hidden = set(blocked)
    inactive = (
        await mongo[c.USERS]
        .find({"status": {"$ne": "active"}}, {"_id": 1})
        .limit(500)
        .to_list(length=500)
    )
    hidden.update(doc["_id"] for doc in inactive)

    base: dict[str, Any] = {
        "visibility": "public",
        "deleted_at": None,
        "moderation.state": "allowed",
    }
    if hidden:
        base["author_id"] = {"$nin": list(hidden)}

    reader = await mongo[c.USERS].find_one({"_id": claims.user_id}, {"interests": 1})
    interest_slugs = await _interest_slugs((reader or {}).get("interests", []), mongo)
    uplifting_slugs = await _uplifting_slugs(mongo)

    phases: list[tuple[str, dict[str, Any] | None]] = [
        ("p", {"$or": personal_clauses} if personal_clauses else None),
        ("i", {"community_slug": {"$in": interest_slugs}} if interest_slugs else None),
        ("u", {"community_slug": {"$in": uplifting_slugs}} if uplifting_slugs else None),
        ("g", None),
    ]
    live = [(key, clause) for key, clause in phases if clause is not None or key == "g"]

    phase, marker = _split_cursor(cursor)
    keys = [key for key, _ in live]
    position = keys.index(phase) if phase in keys else 0

    collected: list[dict[str, Any]] = []
    next_cursor: str | None = None
    has_more = False

    for index in range(position, len(live)):
        key, clause = live[index]
        earlier = [c2 for _, c2 in live[:index] if c2 is not None]
        wanted = limit - len(collected)
        if wanted <= 0:
            break

        query = _phase_query(base, clause, earlier, marker if index == position else None)
        docs = await _fetch(query, mongo=mongo, limit=wanted + 1)

        taken = docs[:wanted]
        collected.extend(taken)

        if len(docs) > wanted:
            next_cursor = f"{key}:{taken[-1]['_id']}"
            has_more = True
            break

        if index + 1 < len(live):
            next_cursor = f"{live[index + 1][0]}:"
            has_more = True
        else:
            next_cursor = None
            has_more = False

    if has_more and next_cursor and next_cursor.endswith(":"):
        next_cursor, has_more = await _first_phase_with_content(
            keys.index(next_cursor[:-1]), live, base, mongo=mongo
        )

    return await _page(
        collected, next_cursor, has_more, viewer_id=claims.user_id, mongo=mongo
    )


def _split_cursor(cursor: str | None) -> tuple[str, str | None]:
    if not cursor:
        return "p", None
    if ":" not in cursor:
        return "g", cursor
    phase, marker = cursor.split(":", 1)
    return (phase if phase in ("p", "g") else "g"), (marker or None)


def _global_query(
    base: dict[str, Any], personal_clauses: list[dict[str, Any]], marker: str | None
) -> dict[str, Any]:
    query = dict(base)
    if personal_clauses:
        query["$nor"] = personal_clauses
    if marker:
        query["_id"] = {"$lt": marker}
    return query


async def _slugs_for_categories(category_ids, mongo) -> list[str]:
    if not category_ids:
        return []
    docs = (
        await mongo[c.COMMUNITIES]
        .find({"category_id": {"$in": list(category_ids)}}, {"_id": 1})
        .to_list(length=500)
    )
    return [doc["_id"] for doc in docs]


async def _interest_slugs(interests, mongo) -> list[str]:
    if not interests:
        return []
    docs = (
        await mongo[c.INTERESTS]
        .find({"_id": {"$in": list(interests)}}, {"category_id": 1})
        .to_list(length=100)
    )
    return await _slugs_for_categories({doc["category_id"] for doc in docs}, mongo)


async def _uplifting_slugs(mongo) -> list[str]:
    docs = (
        await mongo[c.COMMUNITY_CATEGORIES]
        .find({"tone": {"$in": list(c.UPLIFTING_TONES)}}, {"_id": 1})
        .to_list(length=100)
    )
    return await _slugs_for_categories({doc["_id"] for doc in docs}, mongo)


async def _first_phase_with_content(start_index, live, base, *, mongo):
    for index in range(start_index, len(live)):
        key, clause = live[index]
        earlier = [c2 for _, c2 in live[:index] if c2 is not None]
        probe = await _fetch(
            _phase_query(base, clause, earlier, None), mongo=mongo, limit=1
        )
        if probe:
            return f"{key}:", True
    return None, False


def _phase_query(base, clause, earlier, marker):
    query = dict(base)
    if clause:
        query.update(clause)
    if earlier:
        query["$nor"] = earlier
    if marker:
        query["_id"] = {"$lt": marker}
    return query


async def _fetch(query: dict[str, Any], *, mongo, limit: int) -> list[dict[str, Any]]:
    return (
        await mongo[c.STORIES]
        .find(query, c.FEED_PROJECTION)
        .sort("_id", -1)
        .limit(limit)
        .to_list(length=limit)
    )


async def _page(docs, next_cursor, has_more, *, viewer_id=None, mongo=None) -> dict[str, Any]:
    liked = await _liked_story_ids(viewer_id, [doc["_id"] for doc in docs], mongo)
    return {
        "items": await _attach_shared(
            [
                serialize_story(doc, include_body=False, is_liked=doc["_id"] in liked)
                for doc in docs
            ],
            docs,
            mongo,
        ),
        "next_cursor": next_cursor if has_more else None,
        "has_more": has_more,
    }


async def list_community_stories(
    slug: str, *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    community = await mongo["communities"].find_one({"slug": slug, "status": "active"}, {"slug": 1})
    if community is None:
        raise api_error(ErrorCode.COMMUNITY_NOT_FOUND)

    query = {
        "community_slug": slug,
        "visibility": "public",
        "deleted_at": None,
        "moderation.state": "allowed",
    }
    return await _paginate(
        query, mongo=mongo, limit=limit, cursor=cursor, viewer_id=claims.user_id
    )


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
    query: dict[str, Any],
    *,
    mongo: AsyncIOMotorDatabase,
    limit: int,
    cursor: str | None,
    viewer_id: str | None = None,
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
    liked = await _liked_story_ids(viewer_id, [doc["_id"] for doc in page], mongo)
    return {
        "items": await _attach_shared(
            [
                serialize_story(doc, include_body=False, is_liked=doc["_id"] in liked)
                for doc in page
            ],
            page,
            mongo,
        ),
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


def _liker_card(user_id: str, snapshot: dict[str, Any]) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "display_name": snapshot["display_name"],
        "avatar_seed": snapshot["avatar_seed"],
        "username": snapshot.get("username"),
    }


async def _fill_the_gap(story: dict[str, Any], user_id: str, mongo: AsyncIOMotorDatabase) -> None:
    shown = story.get("likers") or []
    if not any(person.get("user_id") == user_id for person in shown):
        return

    left_standing = len(shown) - 1
    still_liked_by = max(0, story.get("counts", {}).get("likes", 0) - 1)
    if still_liked_by <= left_standing:
        return

    fresh, _, _ = await people_who_liked(story["_id"], mongo, limit=c.LIKERS_PREVIEW)
    await mongo[c.STORIES].update_one(
        {"_id": story["_id"]},
        {"$set": {"likers": [_liker_card(person["user_id"], person) for person in fresh]}},
    )


async def people_who_liked(
    story_id: str, mongo: AsyncIOMotorDatabase, *, limit: int, before: str | None = None
) -> tuple[list[dict[str, Any]], bool, str | None]:
    query: dict[str, Any] = {"target_kind": "story", "target_id": story_id, "kind": "like"}
    moment = from_wire(before)
    if moment is not None:
        query["created_at"] = {"$lt": moment}

    reactions = (
        await mongo[c.REACTIONS]
        .find(query, {"user_id": 1, "created_at": 1})
        .sort("created_at", -1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )
    has_more = len(reactions) > limit
    reactions = reactions[:limit]
    if not reactions:
        return [], False, None

    people = (
        await mongo[c.USERS]
        .find(
            {
                "_id": {"$in": [reaction["user_id"] for reaction in reactions]},
                "status": {"$nin": GONE_STATUSES},
                "deleted_at": None,
            },
            {"display_name": 1, "avatar_seed": 1, "username": 1},
        )
        .to_list(length=len(reactions))
    )
    by_id = {person["_id"]: person for person in people}

    liked_by = []
    for reaction in reactions:
        person = by_id.get(reaction["user_id"])
        if person is None:
            continue
        liked_by.append(
            {
                "user_id": person["_id"],
                "display_name": person["display_name"],
                "avatar_seed": person["avatar_seed"],
                "username": person.get("username"),
                "liked_at": to_wire(reaction["created_at"]),
            }
        )
    return liked_by, has_more, to_wire(reactions[-1]["created_at"]) if has_more else None


async def list_story_likes(
    story_id: str, *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    await _readable_story(story_id, claims.user_id, mongo)

    limit = max(1, min(limit, c.FEED_MAX_LIMIT))
    page, has_more, next_cursor = await people_who_liked(
        story_id, mongo, limit=limit, before=cursor
    )

    if page:
        followed = set(
            await mongo["connections"].distinct(
                "followee_id",
                {
                    "follower_id": claims.user_id,
                    "followee_id": {"$in": [person["user_id"] for person in page]},
                    "status": "active",
                },
            )
        )
        for person in page:
            person["is_following"] = person["user_id"] in followed
            person["is_me"] = person["user_id"] == claims.user_id

    return {"items": page, "next_cursor": next_cursor, "has_more": has_more}


async def set_like(
    story_id: str, *, liked: bool, claims, mongo: AsyncIOMotorDatabase, redis=None
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
        snapshot = await _author_snapshot(claims.user_id, mongo) if delta > 0 else None
        changes: dict[str, Any] = {"$inc": {"counts.likes": delta}}
        if snapshot is not None:
            changes["$push"] = {
                "likers": {
                    "$each": [_liker_card(claims.user_id, snapshot)],
                    "$position": 0,
                    "$slice": c.LIKERS_PREVIEW,
                }
            }
        else:
            changes["$pull"] = {"likers": {"user_id": claims.user_id}}

        await mongo[c.STORIES].update_one({"_id": story_id}, changes)

        if delta < 0:
            await _fill_the_gap(story, claims.user_id, mongo)

        if delta > 0:
            await notify(
                mongo=mongo,
                user_id=story["author_id"],
                actor_id=claims.user_id,
                actor_snapshot=snapshot,
                kind="story_like",
                target_kind="story",
                target_id=story_id,
                body="liked your story.",
                collapse=True,
                redis=redis,
)
        else:
            await withdraw(
                mongo=mongo,
                user_id=story["author_id"],
                kind="story_like",
                actor_id=claims.user_id,
                target_id=story_id,
            )

    likes = max(0, story.get("counts", {}).get("likes", 0) + delta)
    return {"likes": likes, "is_liked": liked}


async def create_comment(
    story_id: str,
    body: CreateCommentRequest,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    redis=None,
) -> dict[str, Any]:
    story = await _readable_story(story_id, claims.user_id, mongo)
    parent = None

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

    snapshot = comment["author_snapshot"]

    if parent is not None:
        await mongo[c.COMMENTS].update_one({"_id": body.parent_id}, {"$inc": {"counts.replies": 1}})
        await notify(
            mongo=mongo,
            user_id=parent["author_id"],
            actor_id=claims.user_id,
            actor_snapshot=snapshot,
            kind="comment_reply",
            target_kind="story",
            target_id=story_id,
            body=f"replied: {preview(body.body)}",
            redis=redis,
)

    if parent is None or parent["author_id"] != story["author_id"]:
        await notify(
            mongo=mongo,
            user_id=story["author_id"],
            actor_id=claims.user_id,
            actor_snapshot=snapshot,
            kind="story_comment",
            target_kind="story",
            target_id=story_id,
            body=f"commented: {preview(body.body)}",
            redis=redis,
)

    return {"comment": serialize_comment(comment, can_delete=True)}


async def list_comments(
    story_id: str, *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    story = await _readable_story(story_id, claims.user_id, mongo)
    owns_story = story["author_id"] == claims.user_id

    limit = max(1, min(limit, c.FEED_MAX_LIMIT))
    query: dict[str, Any] = {"story_id": story_id, "parent_id": None, "deleted_at": None}
    if cursor:
        query["_id"] = {"$gt": cursor}

    roots = (
        await mongo[c.COMMENTS]
        .find(query)
        .sort("_id", 1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )
    has_more = len(roots) > limit
    page = roots[:limit]

    replies_by_parent: dict[str, list[dict[str, Any]]] = {}
    if page:
        root_ids = [doc["_id"] for doc in page]
        cursor_replies = (
            mongo[c.COMMENTS]
            .find({"parent_id": {"$in": root_ids}, "deleted_at": None})
            .sort("_id", 1)
        )
        async for reply in cursor_replies:
            replies_by_parent.setdefault(reply["parent_id"], []).append(reply)

    liked_ids = await _liked_comment_ids(
        claims.user_id,
        [doc["_id"] for doc in page]
        + [reply["_id"] for group in replies_by_parent.values() for reply in group],
        mongo,
    )

    items = []
    for doc in page:
        replies = replies_by_parent.get(doc["_id"], [])
        payload = serialize_comment(
            doc,
            is_liked=doc["_id"] in liked_ids,
            can_delete=owns_story or doc["author_id"] == claims.user_id,
        )
        payload["replies"] = [
            serialize_comment(
                reply,
                is_liked=reply["_id"] in liked_ids,
                can_delete=owns_story or reply["author_id"] == claims.user_id,
            )
            for reply in replies[: c.INLINE_REPLIES]
        ]
        payload["counts"] = {**payload.get("counts", {}), "replies": len(replies)}
        items.append(payload)

    return {
        "items": items,
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


async def _liked_story_ids(user_id: str | None, story_ids, mongo) -> set[str]:
    if not user_id or not story_ids:
        return set()
    reaction_ids = [f"{user_id}:story:{story_id}" for story_id in story_ids]
    liked = set()
    async for reaction in mongo[c.REACTIONS].find({"_id": {"$in": reaction_ids}}, {"target_id": 1}):
        liked.add(reaction["target_id"])
    return liked


async def _liked_comment_ids(user_id: str, comment_ids, mongo) -> set[str]:
    if not comment_ids:
        return set()
    reaction_ids = [f"{user_id}:comment:{comment_id}" for comment_id in comment_ids]
    liked = set()
    async for reaction in mongo[c.REACTIONS].find({"_id": {"$in": reaction_ids}}, {"target_id": 1}):
        liked.add(reaction["target_id"])
    return liked


async def list_replies(
    comment_id: str, *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    parent = await mongo[c.COMMENTS].find_one({"_id": comment_id, "deleted_at": None})
    if parent is None:
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)
    story = await _readable_story(parent["story_id"], claims.user_id, mongo)
    owns_story = story["author_id"] == claims.user_id

    limit = max(1, min(limit, c.FEED_MAX_LIMIT))
    query: dict[str, Any] = {"parent_id": comment_id, "deleted_at": None}
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
    liked_ids = await _liked_comment_ids(claims.user_id, [doc["_id"] for doc in page], mongo)

    return {
        "items": [
            serialize_comment(
                doc,
                is_liked=doc["_id"] in liked_ids,
                can_delete=owns_story or doc["author_id"] == claims.user_id,
            )
            for doc in page
        ],
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


async def update_comment(
    comment_id: str, body: UpdateCommentRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    comment = await mongo[c.COMMENTS].find_one(
        {"_id": comment_id, "author_id": claims.user_id, "deleted_at": None}
    )
    if comment is None:
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)

    deadline = comment["created_at"] + timedelta(minutes=c.COMMENT_EDIT_WINDOW_MINUTES)
    if utc_now() > deadline:
        raise api_error(ErrorCode.COMMENT_NOT_EDITABLE)

    now = utc_now()
    await mongo[c.COMMENTS].update_one(
        {"_id": comment_id},
        {"$set": {"body": body.body, "edited_at": now, "updated_at": now}},
    )
    comment.update({"body": body.body, "edited_at": now})
    return {"comment": serialize_comment(comment, can_delete=True)}


async def delete_comment(comment_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    comment = await mongo[c.COMMENTS].find_one({"_id": comment_id, "deleted_at": None})
    if comment is None:
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)

    story = await mongo[c.STORIES].find_one({"_id": comment["story_id"]}, {"author_id": 1})
    is_owner = comment["author_id"] == claims.user_id
    is_story_author = story is not None and story["author_id"] == claims.user_id
    if not (is_owner or is_story_author):
        raise api_error(ErrorCode.COMMENT_NOT_FOUND)

    now = utc_now()
    removed = 1

    if comment.get("parent_id") is None:
        replies = await mongo[c.COMMENTS].update_many(
            {"parent_id": comment_id, "deleted_at": None}, {"$set": {"deleted_at": now}}
        )
        removed += replies.modified_count
    else:
        await mongo[c.COMMENTS].update_one(
            {"_id": comment["parent_id"]}, {"$inc": {"counts.replies": -1}}
        )

    await mongo[c.COMMENTS].update_one({"_id": comment_id}, {"$set": {"deleted_at": now}})
    await mongo[c.STORIES].update_one(
        {"_id": comment["story_id"]}, {"$inc": {"counts.comments": -removed}}
    )
    return {"deleted": True, "comment_id": comment_id, "removed": removed}


async def set_comment_like(
    comment_id: str, *, liked: bool, claims, mongo: AsyncIOMotorDatabase, redis=None
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

        if delta > 0:
            await notify(
                mongo=mongo,
                user_id=comment["author_id"],
                actor_id=claims.user_id,
                actor_snapshot=await _author_snapshot(claims.user_id, mongo),
                kind="comment_like",
                target_kind="story",
                target_id=comment["story_id"],
                body="liked your comment.",
                collapse=True,
                redis=redis,
)
        else:
            await withdraw(
                mongo=mongo,
                user_id=comment["author_id"],
                kind="comment_like",
                actor_id=claims.user_id,
                target_id=comment["story_id"],
            )

    likes = max(0, comment.get("counts", {}).get("likes", 0) + delta)
    return {"likes": likes, "is_liked": liked}
