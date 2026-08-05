from enum import StrEnum
from typing import Any

from fastapi import HTTPException

from app.responses import err_payload


class ErrorCode(StrEnum):
    INVALID_CREDENTIALS = "INVALID_CREDENTIALS"
    TOKEN_EXPIRED = "TOKEN_EXPIRED"
    TOKEN_INVALID = "TOKEN_INVALID"
    TOKEN_REVOKED = "TOKEN_REVOKED"
    TOKEN_REUSED = "TOKEN_REUSED"
    SESSION_REQUIRED = "SESSION_REQUIRED"
    USERNAME_TAKEN = "USERNAME_TAKEN"
    USERNAME_INVALID = "USERNAME_INVALID"
    PASSWORD_TOO_WEAK = "PASSWORD_TOO_WEAK"
    ACCOUNT_BLOCKED = "ACCOUNT_BLOCKED"
    ACCOUNT_DEACTIVATED = "ACCOUNT_DEACTIVATED"
    TNC_REQUIRED = "TNC_REQUIRED"
    REFERRAL_CODE_INVALID = "REFERRAL_CODE_INVALID"
    ROLE_REQUIRED = "ROLE_REQUIRED"

    KEYS_NOT_INITIALIZED = "KEYS_NOT_INITIALIZED"
    KEYS_ALREADY_INITIALIZED = "KEYS_ALREADY_INITIALIZED"

    USER_NOT_FOUND = "USER_NOT_FOUND"
    BIO_LINK_NOT_ALLOWED = "BIO_LINK_NOT_ALLOWED"
    INTEREST_UNKNOWN = "INTEREST_UNKNOWN"
    SESSION_NOT_FOUND = "SESSION_NOT_FOUND"

    STORY_NOT_FOUND = "STORY_NOT_FOUND"
    STORY_NOT_EDITABLE = "STORY_NOT_EDITABLE"
    COMMENT_NOT_FOUND = "COMMENT_NOT_FOUND"
    NESTING_TOO_DEEP = "NESTING_TOO_DEEP"
    NOTIFICATION_NOT_FOUND = "NOTIFICATION_NOT_FOUND"

    VALIDATION_FAILED = "VALIDATION_FAILED"
    RATE_LIMITED = "RATE_LIMITED"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    INTERNAL_ERROR = "INTERNAL_ERROR"


ERROR_SPEC: dict[ErrorCode, tuple[int, str]] = {
    ErrorCode.INVALID_CREDENTIALS: (401, "Those sign-in details did not match."),
    ErrorCode.TOKEN_EXPIRED: (401, "Your session expired. Sign in again."),
    ErrorCode.TOKEN_INVALID: (401, "Your session is not valid. Sign in again."),
    ErrorCode.TOKEN_REVOKED: (401, "This session was signed out. Sign in again."),
    ErrorCode.TOKEN_REUSED: (
        401,
        "For your safety we signed out every session on this device. Sign in again.",
    ),
    ErrorCode.SESSION_REQUIRED: (401, "Sign in to continue."),
    ErrorCode.USERNAME_TAKEN: (409, "That username is already taken."),
    ErrorCode.USERNAME_INVALID: (
        422,
        "Usernames use 3 to 20 lowercase letters, numbers, or underscores.",
    ),
    ErrorCode.PASSWORD_TOO_WEAK: (422, "Choose a longer, less common password."),
    ErrorCode.ACCOUNT_BLOCKED: (403, "This account cannot be used right now."),
    ErrorCode.ACCOUNT_DEACTIVATED: (403, "This account is deactivated."),
    ErrorCode.TNC_REQUIRED: (422, "Accept the terms to continue."),
    ErrorCode.REFERRAL_CODE_INVALID: (422, "That referral code does not exist."),
    ErrorCode.ROLE_REQUIRED: (403, "You do not have access to this."),
    ErrorCode.KEYS_NOT_INITIALIZED: (400, "Finish setting up your account first."),
    ErrorCode.KEYS_ALREADY_INITIALIZED: (409, "Your keys are already set up."),
    ErrorCode.USER_NOT_FOUND: (404, "We could not find that account."),
    ErrorCode.BIO_LINK_NOT_ALLOWED: (422, "Your bio cannot contain a link."),
    ErrorCode.INTEREST_UNKNOWN: (422, "That interest does not exist."),
    ErrorCode.SESSION_NOT_FOUND: (404, "We could not find that session."),
    ErrorCode.STORY_NOT_FOUND: (404, "We could not find that story."),
    ErrorCode.STORY_NOT_EDITABLE: (400, "The edit window for this story has closed."),
    ErrorCode.COMMENT_NOT_FOUND: (404, "We could not find that comment."),
    ErrorCode.NESTING_TOO_DEEP: (400, "Replies only go one level deep."),
    ErrorCode.NOTIFICATION_NOT_FOUND: (404, "We could not find that notification."),
    ErrorCode.VALIDATION_FAILED: (422, "Some of that information is not valid."),
    ErrorCode.RATE_LIMITED: (429, "Too many attempts. Try again shortly."),
    ErrorCode.SERVICE_UNAVAILABLE: (503, "Something we depend on is unavailable."),
    ErrorCode.INTERNAL_ERROR: (500, "Something went wrong on our side."),
}


def api_error(
    code: ErrorCode,
    *,
    message: str | None = None,
    field: str | None = None,
    extra: dict[str, Any] | None = None,
) -> HTTPException:
    status, default_message = ERROR_SPEC[code]
    return HTTPException(
        status_code=status,
        detail=err_payload(message or default_message, code=code.value, field=field, extra=extra),
    )
