from fastapi import APIRouter, status

from app.api.endpoints.tickets import controllers
from app.api.endpoints.tickets.models import CreateTicketRequest
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(tags=["tickets"])


@router.post("/tickets", status_code=status.HTTP_201_CREATED)
async def create_ticket(body: CreateTicketRequest, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.create_ticket(body, claims=claims, mongo=mongo)
    return ok_response("Ticket opened. A person will look at it.", data=data)


@router.get("/tickets", status_code=status.HTTP_200_OK)
async def list_tickets(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.list_tickets(claims=claims, mongo=mongo)
    return ok_response("Your tickets.", data=data)


@router.get("/security-activity", status_code=status.HTTP_200_OK)
async def security_activity(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.security_activity(claims=claims, mongo=mongo)
    return ok_response("Security activity.", data=data)
