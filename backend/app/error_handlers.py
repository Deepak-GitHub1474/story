import traceback

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.logging import build_error_log, get_logger
from app.responses import err_payload

logger = get_logger("story.error")

_STATUS_CODES = {
    401: "SESSION_REQUIRED",
    403: "ROLE_REQUIRED",
    404: "NOT_FOUND",
    405: "METHOD_NOT_ALLOWED",
    409: "CONFLICT",
    413: "PAYLOAD_TOO_LARGE",
    429: "RATE_LIMITED",
}


def _generic_code(status: int) -> str:
    if status in _STATUS_CODES:
        return _STATUS_CODES[status]
    return "INTERNAL_ERROR" if status >= 500 else "VALIDATION_FAILED"


_VALIDATION_MESSAGES = {
    "missing": "This field is required.",
    "string_too_short": "This value is too short.",
    "string_too_long": "This value is too long.",
    "string_pattern_mismatch": "This value is not in the expected format.",
    "value_error": "This value is not valid.",
    "bool_type": "This must be true or false.",
}


def _request_id(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


def _log_error(request: Request, *, message: str, status: int, code: str, where: str | None):
    entry = build_error_log(
        message=message,
        route=request.url.path,
        method=request.method,
        status=status,
        code=code,
        request_id=_request_id(request),
        where=where,
    )
    logger.error("request_failed", **entry)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(request: Request, exc: StarletteHTTPException):
        if isinstance(exc.detail, dict) and "success" in exc.detail:
            body = exc.detail
        else:
            body = err_payload(
                f"{exc.detail}."
                if not str(exc.detail).endswith((".", "!", "?"))
                else str(exc.detail),
                code=_generic_code(exc.status_code),
            )

        if exc.status_code >= 400:
            _log_error(
                request,
                message=body["message"],
                status=exc.status_code,
                code=body["data"].get("code", "UNKNOWN"),
                where=None,
            )
        return JSONResponse(
            status_code=exc.status_code, content=body, headers=getattr(exc, "headers", None)
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(request: Request, exc: RequestValidationError):
        fields = []
        for error in exc.errors():
            location = [str(part) for part in error["loc"] if part not in ("body", "query", "path")]
            name = ".".join(location) or "body"
            fields.append(
                {
                    "field": name,
                    "code": error["type"].upper(),
                    "message": _VALIDATION_MESSAGES.get(error["type"], "This value is not valid."),
                }
            )

        first = fields[0] if fields else {"field": "body", "message": "This request is not valid."}
        body = err_payload(
            first["message"],
            code="VALIDATION_FAILED",
            field=first["field"],
            extra={"fields": fields},
        )
        _log_error(
            request, message=first["message"], status=422, code="VALIDATION_FAILED", where=None
        )
        return JSONResponse(status_code=422, content=body)

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception):
        frame = traceback.extract_tb(exc.__traceback__)[-1] if exc.__traceback__ else None
        where = f"{frame.filename.split('/')[-1]}:{frame.lineno}" if frame else None

        _log_error(
            request,
            message=f"{type(exc).__name__}: {exc}",
            status=500,
            code="INTERNAL_ERROR",
            where=where,
        )
        logger.error(
            "unhandled_exception",
            route=request.url.path,
            method=request.method,
            error=f"{type(exc).__name__}: {exc}",
            where=where,
            exc_info=exc,
        )

        return JSONResponse(
            status_code=500,
            content=err_payload("Something went wrong on our side.", code="INTERNAL_ERROR"),
        )
