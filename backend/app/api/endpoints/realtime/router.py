import json

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status

from app.api.endpoints.chat import controllers as chat_controllers
from app.api.endpoints.realtime import controllers
from app.core.deps import CurrentClaims
from app.db.redis import RedisClient
from app.logging import get_logger
from app.realtime.hub import hub
from app.responses import ok_response

logger = get_logger("story.realtime.ws")

router = APIRouter(tags=["realtime"])


@router.post("/realtime/ticket", status_code=status.HTTP_201_CREATED)
async def issue_ticket(claims: CurrentClaims, redis: RedisClient):
    data = await controllers.issue_ticket(claims.user_id, redis=redis)
    return ok_response("Socket ticket. It lasts seconds and is used once.", data=data)


@router.websocket("/ws")
async def realtime(websocket: WebSocket, ticket: str = Query(default="")):
    redis = websocket.app.state.redis
    user_id = await controllers.claim_ticket(ticket, redis=redis)
    if user_id is None:
        await websocket.close(code=4401)
        return

    await websocket.accept()
    hub.attach(user_id, websocket)
    await chat_controllers.mark_online(user_id, redis=redis)

    try:
        while True:
            raw = await websocket.receive_text()
            await _handle(raw, user_id=user_id, redis=redis)
    except WebSocketDisconnect:
        pass
    finally:
        hub.detach(user_id, websocket)
        if not hub.is_online(user_id):
            await chat_controllers.mark_offline(user_id, redis=redis)


async def _handle(raw: str, *, user_id: str, redis) -> None:
    try:
        event = json.loads(raw)
    except ValueError:
        return

    if not isinstance(event, dict):
        return

    if event.get("type") == "ping":
        await chat_controllers.mark_online(user_id, redis=redis)
