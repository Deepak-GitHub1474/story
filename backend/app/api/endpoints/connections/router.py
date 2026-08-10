from fastapi import APIRouter, status

from app.api.endpoints.connections import controllers
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/connections", tags=["connections"])


@router.get("/following", status_code=status.HTTP_200_OK)
async def list_following(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.list_following(claims=claims, mongo=mongo)
    return ok_response("Following.", data=data)


@router.get("/followers", status_code=status.HTTP_200_OK)
async def list_followers(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.list_followers(claims=claims, mongo=mongo)
    return ok_response("Readers.", data=data)


@router.get("/blocked", status_code=status.HTTP_200_OK)
async def list_blocked(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.list_blocked(claims=claims, mongo=mongo)
    return ok_response("Blocked accounts.", data=data)


@router.post("/{username}", status_code=status.HTTP_200_OK)
async def follow(
    username: str, claims: CurrentClaims, mongo: MongoDatabase, redis: RedisClient
):
    data = await controllers.follow(username, claims=claims, mongo=mongo, redis=redis)
    return ok_response("Following.", data=data)


@router.delete("/{username}", status_code=status.HTTP_200_OK)
async def unfollow(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.unfollow(username, claims=claims, mongo=mongo)
    return ok_response("Unfollowed.", data=data)


@router.post("/{username}/block", status_code=status.HTTP_200_OK)
async def block(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.block(username, claims=claims, mongo=mongo)
    return ok_response("Blocked.", data=data)


@router.delete("/{username}/block", status_code=status.HTTP_200_OK)
async def unblock(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.unblock(username, claims=claims, mongo=mongo)
    return ok_response("Unblocked.", data=data)
