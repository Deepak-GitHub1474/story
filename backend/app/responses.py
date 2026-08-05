from typing import Any

TERMINAL_PUNCTUATION = (".", "!", "?")
RESERVED_ERROR_KEYS = frozenset({"code", "field"})


def _validate_message(message: str) -> str:
    if not message.strip():
        raise ValueError("Message must not be empty.")
    if not message.rstrip().endswith(TERMINAL_PUNCTUATION):
        raise ValueError(f"Message must be a sentence with terminal punctuation: {message!r}")
    return message


def ok_response(message: str, data: Any = None) -> dict[str, Any]:
    return {"success": True, "message": _validate_message(message), "data": data}


def err_payload(
    message: str,
    *,
    code: str,
    field: str | None = None,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if code != code.upper() or not code.replace("_", "").isalnum():
        raise ValueError(f"Error code must be SCREAMING_SNAKE_CASE: {code!r}")

    data: dict[str, Any] = {"code": code}
    if field is not None:
        data["field"] = field
    if extra:
        collisions = RESERVED_ERROR_KEYS & extra.keys()
        if collisions:
            raise ValueError(f"Extra context may not use reserved keys: {sorted(collisions)}")
        data.update(extra)

    return {"success": False, "message": _validate_message(message), "data": data}
