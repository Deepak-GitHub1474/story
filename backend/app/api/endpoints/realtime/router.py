from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status

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
    user_id = await controllers.claim_ticket(
        ticket, redis=websocket.app.state.redis
    )
    if user_id is None:
        await websocket.close(code=4401)
        return

    await websocket.accept()
    hub.attach(user_id, websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        hub.detach(user_id, websocket)
