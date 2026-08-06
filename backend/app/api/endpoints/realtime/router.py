from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.config import get_settings
from app.core.tokens import decode_access_token
from app.logging import get_logger
from app.realtime.hub import hub

logger = get_logger("story.realtime.ws")

router = APIRouter(tags=["realtime"])


@router.websocket("/ws")
async def realtime(websocket: WebSocket, token: str = Query(default="")):
    settings = get_settings()

    try:
        claims = decode_access_token(token, secret=settings.JWT_SECRET)
    except Exception:
        await websocket.close(code=4401)
        return

    await websocket.accept()
    hub.attach(claims.user_id, websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        hub.detach(claims.user_id, websocket)
