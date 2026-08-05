import secrets
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from app.logging import get_logger

logger = get_logger("story.request")

REQUEST_ID_HEADER = "x-request-id"

SECURITY_HEADERS = {
    "x-content-type-options": "nosniff",
    "referrer-policy": "no-referrer",
    "x-frame-options": "DENY",
    "permissions-policy": "camera=(), microphone=(), geolocation=()",
    "cross-origin-opener-policy": "same-origin",
}


class RequestContextMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request, call_next):
        request_id = request.headers.get(REQUEST_ID_HEADER) or f"req_{secrets.token_hex(8)}"
        request.state.request_id = request_id
        started = time.perf_counter()

        response = await call_next(request)

        duration_ms = int((time.perf_counter() - started) * 1000)
        response.headers[REQUEST_ID_HEADER] = request_id
        for header, value in SECURITY_HEADERS.items():
            response.headers.setdefault(header, value)

        logger.info(
            "request_completed",
            request_id=request_id,
            method=request.method,
            route=request.url.path,
            status=response.status_code,
            duration_ms=duration_ms,
        )
        return response
