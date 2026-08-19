from fastapi import APIRouter, status

from app.api.endpoints.stories.constants import STORIES, USERS
from app.core.errors import ErrorCode, api_error
from app.core.time import to_wire
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(prefix="/public", tags=["public"])

PROJECTION = {
    "_id": 1,
    "author_id": 1,
    "community": 1,
    "title": 1,
    "body": 1,
    "excerpt": 1,
    "slug": 1,
    "counts": 1,
    "reading_minutes": 1,
    "published_at": 1,
}


@router.get("/stories/{slug}", status_code=status.HTTP_200_OK)
async def public_story(slug: str, mongo: MongoDatabase):
    story = await mongo[STORIES].find_one(
        {
            "slug": slug,
            "visibility": "public",
            "deleted_at": None,
            "moderation.state": "allowed",
        },
        PROJECTION,
    )
    if story is None:
        raise api_error(ErrorCode.STORY_NOT_FOUND)

    author = await mongo[USERS].find_one(
        {"_id": story["author_id"], "deleted_at": None},
        {"blocked": 1, "status": 1, "username": 1, "display_name": 1, "avatar_seed": 1},
    )
    if author is None or author.get("blocked") or author.get("status") != "active":
        raise api_error(ErrorCode.STORY_NOT_FOUND)

    return ok_response(
        "Story loaded.",
        data={
            "story": {
                "slug": story["slug"],
                "title": story.get("title"),
                "body": story.get("body", ""),
                "excerpt": story.get("excerpt", ""),
                "author": {
                    "display_name": author.get("display_name", "Someone"),
                    "avatar_seed": author.get("avatar_seed", ""),
                    "username": author["username"],
                },
                "community": story.get("community"),
                "counts": story.get("counts", {}),
                "reading_minutes": story.get("reading_minutes", 1),
                "published_at": to_wire(story.get("published_at")),
            }
        },
    )
