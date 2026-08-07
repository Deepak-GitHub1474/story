from fastapi import APIRouter, status

from app.api.endpoints.suggestions import controllers
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(tags=["suggestions"])


@router.get("/suggestions", status_code=status.HTTP_200_OK)
async def suggestions(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.suggestions(claims=claims, mongo=mongo)
    return ok_response("Rooms and people you might like.", data=data)
