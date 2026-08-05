from fastapi import APIRouter, Depends, status

from app.api.endpoints.reports import controllers
from app.api.endpoints.reports.models import CreateReportRequest
from app.core.deps import CurrentClaims, rate_limit_dep
from app.db.mongo import MongoDatabase
from app.responses import ok_response

router = APIRouter(tags=["reports"])


@router.post(
    "/reports",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("report_create", 30, 3600))],
)
async def create_report(body: CreateReportRequest, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.create_report(body, claims=claims, mongo=mongo)
    return ok_response("Thank you. A person will look at this.", data=data)
