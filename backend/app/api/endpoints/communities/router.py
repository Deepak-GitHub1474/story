from fastapi import APIRouter, status

from app.api.endpoints.communities import controllers
from app.api.endpoints.stories import controllers as story_controllers
from app.api.endpoints.stories.constants import FEED_DEFAULT_LIMIT
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(prefix="/communities", tags=["communities"])


@router.get("/categories", status_code=status.HTTP_200_OK)
async def list_categories(mongo: MongoDatabase):
    data = await controllers.list_categories(mongo=mongo)
    return ok_response("Categories loaded.", data=data)


@router.get("/me", status_code=status.HTTP_200_OK)
async def my_communities(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.my_communities(claims=claims, mongo=mongo)
    return ok_response("Your communities.", data=data)


@router.get("", status_code=status.HTTP_200_OK)
async def list_communities(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    category: str | None = None,
    q: str | None = None,
):
    data = await controllers.list_communities(
        claims=claims, mongo=mongo, category=category, query=q
    )
    return ok_response("Communities loaded.", data=data)


@router.get("/{slug}", status_code=status.HTTP_200_OK)
async def community_detail(slug: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.community_detail(slug, claims=claims, mongo=mongo)
    return ok_response("Community loaded.", data=data)


@router.post("/{slug}/join", status_code=status.HTTP_200_OK)
async def join(slug: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.join(slug, claims=claims, mongo=mongo)
    return ok_response("Joined.", data=data)


@router.delete("/{slug}/join", status_code=status.HTTP_200_OK)
async def leave(slug: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.leave(slug, claims=claims, mongo=mongo)
    return ok_response("Left the community.", data=data)


@router.get("/{slug}/stories", status_code=status.HTTP_200_OK)
async def community_stories(
    slug: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = FEED_DEFAULT_LIMIT,
    cursor: str | None = None,
):
    data = await story_controllers.list_community_stories(
        slug, claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("Community stories.", data=data)
