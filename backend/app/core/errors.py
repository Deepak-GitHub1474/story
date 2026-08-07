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
    DELETION_NOT_ACKNOWLEDGED = "DELETION_NOT_ACKNOWLEDGED"
    TNC_REQUIRED = "TNC_REQUIRED"
    REFERRAL_CODE_INVALID = "REFERRAL_CODE_INVALID"
    ROLE_REQUIRED = "ROLE_REQUIRED"
    TICKET_NOT_FOUND = "TICKET_NOT_FOUND"
    TICKET_ALREADY_OPEN = "TICKET_ALREADY_OPEN"
    TOTP_REQUIRED = "TOTP_REQUIRED"
    TOTP_INVALID = "TOTP_INVALID"
    TOTP_REUSED = "TOTP_REUSED"
    TOTP_ALREADY_ENABLED = "TOTP_ALREADY_ENABLED"
    CHAT_NO_IDENTITY = "CHAT_NO_IDENTITY"
    CHAT_NO_BACKUP = "CHAT_NO_BACKUP"
    CHAT_SELF = "CHAT_SELF"
    CHAT_BLOCKED = "CHAT_BLOCKED"
    CHAT_NOT_YOURS_TO_ACCEPT = "CHAT_NOT_YOURS_TO_ACCEPT"
    CONVERSATION_NOT_FOUND = "CONVERSATION_NOT_FOUND"
    MESSAGE_NOT_FOUND = "MESSAGE_NOT_FOUND"

    EMAIL_ALREADY_SET = "EMAIL_ALREADY_SET"
    EMAIL_IN_USE = "EMAIL_IN_USE"
    EMAIL_NOT_SET = "EMAIL_NOT_SET"
    EMAIL_NOT_VERIFIED = "EMAIL_NOT_VERIFIED"
    OTP_INVALID = "OTP_INVALID"
    OTP_LOCKED = "OTP_LOCKED"
    OTP_COOLDOWN = "OTP_COOLDOWN"
    RESET_TOKEN_INVALID = "RESET_TOKEN_INVALID"
    VAULT_LOSS_NOT_ACKNOWLEDGED = "VAULT_LOSS_NOT_ACKNOWLEDGED"
    KEYS_NOT_INITIALIZED = "KEYS_NOT_INITIALIZED"
    KEYS_ALREADY_INITIALIZED = "KEYS_ALREADY_INITIALIZED"
    VAULT_ITEM_NOT_FOUND = "VAULT_ITEM_NOT_FOUND"
    PASSCODE_NOT_FOUND = "PASSCODE_NOT_FOUND"
    PASSCODE_LABEL_TAKEN = "PASSCODE_LABEL_TAKEN"
    LABEL_REQUIRED = "LABEL_REQUIRED"
    LABEL_TAKEN = "LABEL_TAKEN"
    QUOTA_EXCEEDED = "QUOTA_EXCEEDED"
    ITEM_TOO_LARGE = "ITEM_TOO_LARGE"
    ITEM_NOT_READY = "ITEM_NOT_READY"
    ITEM_ORPHANED = "ITEM_ORPHANED"
    UPLOAD_MISMATCH = "UPLOAD_MISMATCH"

    USER_NOT_FOUND = "USER_NOT_FOUND"
    BIO_LINK_NOT_ALLOWED = "BIO_LINK_NOT_ALLOWED"
    INTEREST_UNKNOWN = "INTEREST_UNKNOWN"
    SESSION_NOT_FOUND = "SESSION_NOT_FOUND"

    STORY_NOT_FOUND = "STORY_NOT_FOUND"
    STORY_NOT_EDITABLE = "STORY_NOT_EDITABLE"
    STORY_NOT_SHAREABLE = "STORY_NOT_SHAREABLE"
    SCHEDULE_REQUIRED = "SCHEDULE_REQUIRED"
    SCHEDULE_IN_PAST = "SCHEDULE_IN_PAST"
    COMMENT_NOT_EDITABLE = "COMMENT_NOT_EDITABLE"
    COMMENT_NOT_FOUND = "COMMENT_NOT_FOUND"
    NESTING_TOO_DEEP = "NESTING_TOO_DEEP"
    COMMUNITY_NOT_FOUND = "COMMUNITY_NOT_FOUND"
    NOT_A_MEMBER = "NOT_A_MEMBER"
    SELF_FOLLOW = "SELF_FOLLOW"
    BLOCKED_BY_USER = "BLOCKED_BY_USER"
    NOTIFICATION_NOT_FOUND = "NOTIFICATION_NOT_FOUND"
    REPORT_TARGET_NOT_FOUND = "REPORT_TARGET_NOT_FOUND"
    SELF_REPORT = "SELF_REPORT"

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
        "Use 2 to 30 letters, numbers, underscores or hyphens. It must "
        "start and end with a letter or number.",
    ),
    ErrorCode.PASSWORD_TOO_WEAK: (422, "Choose a longer, less common password."),
    ErrorCode.ACCOUNT_BLOCKED: (403, "This account cannot be used right now."),
    ErrorCode.ACCOUNT_DEACTIVATED: (403, "This account is deactivated."),
    ErrorCode.DELETION_NOT_ACKNOWLEDGED: (
        422,
        "You must acknowledge that deletion is permanent.",
    ),
    ErrorCode.TNC_REQUIRED: (422, "Accept the terms to continue."),
    ErrorCode.REFERRAL_CODE_INVALID: (422, "That referral code does not exist."),
    ErrorCode.ROLE_REQUIRED: (403, "You do not have access to this."),
    ErrorCode.TICKET_NOT_FOUND: (404, "We could not find that ticket."),
    ErrorCode.TICKET_ALREADY_OPEN: (409, "You already have an open request of this kind."),
    ErrorCode.TOTP_REQUIRED: (403, "Set up an authenticator app before doing this."),
    ErrorCode.TOTP_INVALID: (403, "That code is not right."),
    ErrorCode.TOTP_REUSED: (403, "That code has already been used. Wait for the next one."),
    ErrorCode.TOTP_ALREADY_ENABLED: (409, "An authenticator is already set up on this account."),
    ErrorCode.CHAT_NO_IDENTITY: (404, "That account has not set up chat yet."),
    ErrorCode.CHAT_NO_BACKUP: (404, "No chat key backup on this account yet."),
    ErrorCode.CHAT_SELF: (422, "You cannot message yourself."),
    ErrorCode.CHAT_BLOCKED: (403, "You cannot message this account."),
    ErrorCode.CHAT_NOT_YOURS_TO_ACCEPT: (403, "Only the person who received it can accept."),
    ErrorCode.CONVERSATION_NOT_FOUND: (404, "We could not find that chat."),
    ErrorCode.MESSAGE_NOT_FOUND: (404, "We could not find that message."),
    ErrorCode.EMAIL_ALREADY_SET: (409, "An address is already on this account."),
    ErrorCode.EMAIL_IN_USE: (409, "That address is already in use."),
    ErrorCode.EMAIL_NOT_SET: (400, "Add an email address first."),
    ErrorCode.EMAIL_NOT_VERIFIED: (403, "Verify your email address first."),
    ErrorCode.OTP_INVALID: (400, "That code is not right."),
    ErrorCode.OTP_LOCKED: (429, "Too many attempts. Try again later."),
    ErrorCode.OTP_COOLDOWN: (429, "Wait a moment before asking for another code."),
    ErrorCode.RESET_TOKEN_INVALID: (400, "That reset link is no longer valid."),
    ErrorCode.VAULT_LOSS_NOT_ACKNOWLEDGED: (
        422,
        "You must acknowledge that a reset cannot restore your vault.",
    ),
    ErrorCode.KEYS_NOT_INITIALIZED: (400, "Finish setting up your account first."),
    ErrorCode.KEYS_ALREADY_INITIALIZED: (409, "Your keys are already set up."),
    ErrorCode.VAULT_ITEM_NOT_FOUND: (404, "We could not find that item."),
    ErrorCode.PASSCODE_NOT_FOUND: (404, "We could not find that passcode."),
    ErrorCode.PASSCODE_LABEL_TAKEN: (409, "You already have a passcode with that name."),
    ErrorCode.LABEL_REQUIRED: (422, "A hidden item needs a label."),
    ErrorCode.LABEL_TAKEN: (409, "You already used that label."),
    ErrorCode.QUOTA_EXCEEDED: (400, "Your vault is full."),
    ErrorCode.ITEM_TOO_LARGE: (413, "That file is too large for the vault."),
    ErrorCode.ITEM_NOT_READY: (400, "That upload has not finished."),
    ErrorCode.ITEM_ORPHANED: (400, "This item can no longer be decrypted."),
    ErrorCode.UPLOAD_MISMATCH: (400, "The upload does not match what was declared."),
    ErrorCode.USER_NOT_FOUND: (404, "We could not find that account."),
    ErrorCode.BIO_LINK_NOT_ALLOWED: (422, "Your bio cannot contain a link."),
    ErrorCode.INTEREST_UNKNOWN: (422, "That interest does not exist."),
    ErrorCode.SESSION_NOT_FOUND: (404, "We could not find that session."),
    ErrorCode.STORY_NOT_FOUND: (404, "We could not find that story."),
    ErrorCode.STORY_NOT_EDITABLE: (400, "The edit window for this story has closed."),
    ErrorCode.STORY_NOT_SHAREABLE: (400, "Only public stories can be shared."),
    ErrorCode.SCHEDULE_REQUIRED: (422, "Choose when this should publish."),
    ErrorCode.SCHEDULE_IN_PAST: (422, "Choose a time in the future."),
    ErrorCode.COMMENT_NOT_EDITABLE: (400, "The edit window for this comment has closed."),
    ErrorCode.COMMENT_NOT_FOUND: (404, "We could not find that comment."),
    ErrorCode.NESTING_TOO_DEEP: (400, "Replies only go one level deep."),
    ErrorCode.COMMUNITY_NOT_FOUND: (404, "We could not find that community."),
    ErrorCode.NOT_A_MEMBER: (403, "Join this community before posting in it."),
    ErrorCode.SELF_FOLLOW: (400, "You cannot follow yourself."),
    ErrorCode.BLOCKED_BY_USER: (403, "This is not available."),
    ErrorCode.NOTIFICATION_NOT_FOUND: (404, "We could not find that notification."),
    ErrorCode.REPORT_TARGET_NOT_FOUND: (404, "We could not find what you reported."),
    ErrorCode.SELF_REPORT: (400, "You cannot report your own content."),
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
