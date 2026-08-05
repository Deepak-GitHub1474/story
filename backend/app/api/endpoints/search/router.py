from typing import Literal

from fastapi import APIRouter, Query, status

from app.api.endpoints.search import controllers
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(tags=["search"])


@router.get("/search", status_code=status.HTTP_200_OK)
async def search(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    q: str = Query(min_length=1, max_length=80),
    kind: Literal["all", "users", "communities", "stories"] = "all",
):
    data = await controllers.search(query=q, kind=kind, claims=claims, mongo=mongo)
    return ok_response("Search results.", data=data)
