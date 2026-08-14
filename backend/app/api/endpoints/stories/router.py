from typing import Annotated

from fastapi import APIRouter, Depends, Request, status

from app.api.endpoints.stories import controllers
from app.api.endpoints.stories.constants import FEED_DEFAULT_LIMIT, LIKES_PAGE_LIMIT
from app.api.endpoints.stories.models import (
    CreateCommentRequest,
    CreateStoryRequest,
    PublishStoryRequest,
    UpdateCommentRequest,
    UpdateStoryRequest,
)
from app.core.deps import AI, AppSettings, CurrentClaims, rate_limit_dep
from app.core.idempotency import remember, replay
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.ports.factory import build_storage
from app.ports.storage import StoragePort
from app.responses import ok_response


def _storage(settings: AppSettings) -> StoragePort:
    return build_storage(settings)


Storage = Annotated[StoragePort, Depends(_storage)]

router = APIRouter(tags=["stories"])


@router.post(
    "/stories",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("story_create", 40, 3600))],
)
async def create_story(
    request: Request,
    body: CreateStoryRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    cached = await replay(request, user_id=claims.user_id, redis=redis)
    if cached is not None:
        return ok_response("Saved to your drafts.", data=cached)

    data = await controllers.create_story(body, claims=claims, mongo=mongo)
    await remember(request, user_id=claims.user_id, redis=redis, payload=data)
    return ok_response("Saved to your drafts.", data=data)


@router.get("/stories/mine", status_code=status.HTTP_200_OK)
async def list_mine(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    visibility: str | None = None,
    limit: int = FEED_DEFAULT_LIMIT,
    cursor: str | None = None,
):
    data = await controllers.list_mine(
        claims=claims, mongo=mongo, visibility=visibility, limit=limit, cursor=cursor
    )
    return ok_response("Your stories.", data=data)


@router.get("/stories/feed", status_code=status.HTTP_200_OK)
async def list_feed(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = FEED_DEFAULT_LIMIT,
    cursor: str | None = None,
):
    data = await controllers.list_feed(claims=claims, mongo=mongo, limit=limit, cursor=cursor)
    return ok_response("Feed loaded.", data=data)


@router.get("/stories/{story_id}", status_code=status.HTTP_200_OK)
async def get_story(story_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.get_story(story_id, claims=claims, mongo=mongo)
    return ok_response("Story loaded.", data=data)


@router.patch("/stories/{story_id}", status_code=status.HTTP_200_OK)
async def update_story(
    story_id: str,
    body: UpdateStoryRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    storage: Storage,
):
    data = await controllers.update_story(
        story_id, body, claims=claims, mongo=mongo, storage=storage
    )
    return ok_response("Saved.", data=data)


@router.delete("/stories/{story_id}", status_code=status.HTTP_200_OK)
async def delete_story(
    story_id: str, claims: CurrentClaims, mongo: MongoDatabase, storage: Storage
):
    data = await controllers.delete_story(
        story_id, claims=claims, mongo=mongo, storage=storage
    )
    return ok_response("Story deleted.", data=data)


@router.post("/stories/{story_id}/publish", status_code=status.HTTP_200_OK)
async def publish_story(
    story_id: str,
    body: PublishStoryRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    ai: AI,
    redis: RedisClient,
):
    data = await controllers.publish_story(
        story_id, body, claims=claims, mongo=mongo, ai=ai, redis=redis
    )
    message = "Your story is live." if body.visibility == "public" else "Saved as private."
    return ok_response(message, data=data)


@router.post("/stories/{story_id}/unpublish", status_code=status.HTTP_200_OK)
async def unpublish_story(story_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.unpublish_story(story_id, claims=claims, mongo=mongo)
    return ok_response("Moved back to drafts.", data=data)


@router.post("/stories/{story_id}/share", status_code=status.HTTP_200_OK)
async def share_story(
    story_id: str, claims: CurrentClaims, mongo: MongoDatabase, settings: AppSettings
):
    data = await controllers.share_story(
        story_id, claims=claims, mongo=mongo, base_url=settings.PUBLIC_WEB_URL
    )
    return ok_response("Link ready to share.", data=data)


@router.post("/stories/{story_id}/like", status_code=status.HTTP_200_OK)
async def like_story(
    story_id: str, claims: CurrentClaims, mongo: MongoDatabase, redis: RedisClient
):
    data = await controllers.set_like(
        story_id, liked=True, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Liked.", data=data)


@router.delete("/stories/{story_id}/like", status_code=status.HTTP_200_OK)
async def unlike_story(
    story_id: str, claims: CurrentClaims, mongo: MongoDatabase, redis: RedisClient
):
    data = await controllers.set_like(
        story_id, liked=False, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Unliked.", data=data)


@router.get("/stories/{story_id}/likes", status_code=status.HTTP_200_OK)
async def list_story_likes(
    story_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = LIKES_PAGE_LIMIT,
    cursor: str | None = None,
):
    data = await controllers.list_story_likes(
        story_id, claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("Likes loaded.", data=data)


@router.get("/stories/{story_id}/comments", status_code=status.HTTP_200_OK)
async def list_comments(
    story_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = FEED_DEFAULT_LIMIT,
    cursor: str | None = None,
):
    data = await controllers.list_comments(
        story_id, claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("Comments loaded.", data=data)


@router.post(
    "/stories/{story_id}/comments",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("comment_create", 120, 3600))],
)
async def create_comment(
    request: Request,
    story_id: str,
    body: CreateCommentRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    cached = await replay(request, user_id=claims.user_id, redis=redis)
    if cached is not None:
        return ok_response("Comment added.", data=cached)

    data = await controllers.create_comment(
        story_id, body, claims=claims, mongo=mongo, redis=redis
    )
    await remember(request, user_id=claims.user_id, redis=redis, payload=data)
    return ok_response("Comment added.", data=data)


@router.get("/comments/{comment_id}/replies", status_code=status.HTTP_200_OK)
async def list_replies(
    comment_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = FEED_DEFAULT_LIMIT,
    cursor: str | None = None,
):
    data = await controllers.list_replies(
        comment_id, claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("Replies loaded.", data=data)


@router.patch("/comments/{comment_id}", status_code=status.HTTP_200_OK)
async def update_comment(
    comment_id: str,
    body: UpdateCommentRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.update_comment(comment_id, body, claims=claims, mongo=mongo)
    return ok_response("Comment updated.", data=data)


@router.delete("/comments/{comment_id}", status_code=status.HTTP_200_OK)
async def delete_comment(comment_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.delete_comment(comment_id, claims=claims, mongo=mongo)
    return ok_response("Comment deleted.", data=data)


@router.post("/comments/{comment_id}/like", status_code=status.HTTP_200_OK)
async def like_comment(
    comment_id: str, claims: CurrentClaims, mongo: MongoDatabase, redis: RedisClient
):
    data = await controllers.set_comment_like(
        comment_id, liked=True, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Liked.", data=data)


@router.delete("/comments/{comment_id}/like", status_code=status.HTTP_200_OK)
async def unlike_comment(
    comment_id: str, claims: CurrentClaims, mongo: MongoDatabase, redis: RedisClient
):
    data = await controllers.set_comment_like(
        comment_id, liked=False, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Unliked.", data=data)


@router.get("/users/{username}/stories", status_code=status.HTTP_200_OK)
async def list_user_stories(
    username: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = FEED_DEFAULT_LIMIT,
    cursor: str | None = None,
):
    data = await controllers.list_user_stories(username, mongo=mongo, limit=limit, cursor=cursor)
    return ok_response("Stories loaded.", data=data)
