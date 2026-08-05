import logging
import sys
from typing import Any

import structlog

from app.core.time import to_wire, utc_now

REDACTED = "<redacted>"

ALLOWED_KEYS: frozenset[str] = frozenset(
    {
        "user_id",
        "username",
        "item_id",
        "story_id",
        "comment_id",
        "community_id",
        "ticket_id",
        "review_id",
        "request_id",
        "family_id",
        "jti",
        "route",
        "path",
        "method",
        "status",
        "code",
        "error",
        "event",
        "time",
        "level",
        "duration_ms",
        "where",
        "service",
        "env",
        "version",
        "client_version",
        "platform",
        "ip_prefix",
        "count",
        "attempt",
    }
)

DENIED_FRAGMENTS: tuple[str, ...] = (
    "password",
    "passcode",
    "otp",
    "token",
    "refresh",
    "authorization",
    "cookie",
    "secret",
    "umk",
    "dek",
    "kek",
    "salt",
    "email",
    "label",
    "recovery",
    "encrypted",
    "escrow",
    "hash",
)


def _is_denied(key: str) -> bool:
    lowered = key.lower()
    return any(fragment in lowered for fragment in DENIED_FRAGMENTS)


def _is_allowed(key: str) -> bool:
    return not _is_denied(key) and key.lower() in ALLOWED_KEYS


def _redact_value(key: str, value: Any) -> Any:
    if _is_denied(key):
        return REDACTED
    if isinstance(value, dict | list):
        return redact(value)
    return value if _is_allowed(key) else REDACTED


def redact(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _redact_value(key, inner) for key, inner in value.items()}
    if isinstance(value, list):
        return [redact(item) for item in value]
    return value


def build_error_log(
    *,
    message: str,
    route: str,
    method: str,
    status: int,
    code: str | None = None,
    request_id: str | None = None,
    where: str | None = None,
) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "time": to_wire(utc_now()),
        "level": "error",
        "error": message,
        "route": route,
        "method": method,
        "status": status,
    }
    if code:
        entry["code"] = code
    if request_id:
        entry["request_id"] = request_id
    if where:
        entry["where"] = where
    return entry


def _redaction_processor(_logger, _name, event_dict):
    reserved = {"event", "level", "timestamp", "time", "logger", "exc_info"}
    return {
        key: (value if key in reserved else redact({key: value})[key])
        for key, value in event_dict.items()
    }


def configure_logging(*, env: str, level: str = "INFO") -> None:
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=level)

    renderer = (
        structlog.dev.ConsoleRenderer(colors=True)
        if env == "local"
        else structlog.processors.JSONRenderer()
    )

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True, key="time"),
            _redaction_processor,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            renderer,
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.getLevelNamesMapping()[level]),
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> Any:
    return structlog.get_logger(name)
