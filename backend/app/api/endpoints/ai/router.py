from fastapi import APIRouter, Depends, status

from app.adapters.ai_gemini import ModerationUnavailable
from app.api.endpoints.ai.models import DraftRequest, PolishRequest
from app.core.deps import AI, CurrentClaims, rate_limit_dep
from app.core.errors import ErrorCode, api_error
from app.responses import ok_response

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post(
    "/polish",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("ai_polish", 20, 3600))],
)
async def polish(body: PolishRequest, claims: CurrentClaims, ai: AI):
    if not body.text.strip():
        raise api_error(ErrorCode.VALIDATION_FAILED, field="text")

    try:
        text = await ai.polish(text=body.text, instruction=body.instruction)
    except ModerationUnavailable:
        raise api_error(ErrorCode.AI_UNAVAILABLE) from None

    return ok_response("Here is another go at it.", data={"text": text})


@router.post(
    "/draft",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("ai_draft", 10, 3600))],
)
async def draft(body: DraftRequest, claims: CurrentClaims, ai: AI):
    if not body.brief.strip() or not body.subject.strip():
        raise api_error(ErrorCode.VALIDATION_FAILED, field="brief")

    try:
        written = await ai.draft_story(
            subject=body.subject.strip(), brief=body.brief.strip()
        )
    except ModerationUnavailable:
        raise api_error(ErrorCode.AI_UNAVAILABLE) from None

    return ok_response(
        "Here is a first draft.",
        data={"title": written.title, "body": written.body},
    )
