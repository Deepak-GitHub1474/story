import pytest
from fastapi import HTTPException

from app.core.errors import ErrorCode, api_error


def test_api_error_is_an_http_exception_fastapi_can_raise():
    assert isinstance(api_error(ErrorCode.USERNAME_TAKEN), HTTPException)


def test_api_error_uses_the_status_declared_for_the_code():
    assert api_error(ErrorCode.USERNAME_TAKEN).status_code == 409


def test_api_error_detail_is_the_full_envelope_so_handlers_emit_it_verbatim():
    detail = api_error(ErrorCode.USERNAME_TAKEN).detail
    assert set(detail.keys()) == {"success", "message", "data"}
    assert detail["success"] is False


def test_api_error_carries_its_code():
    assert api_error(ErrorCode.USERNAME_TAKEN).detail["data"]["code"] == "USERNAME_TAKEN"


def test_api_error_uses_the_default_message_for_the_code():
    assert api_error(ErrorCode.USERNAME_TAKEN).detail["message"].endswith(".")


def test_api_error_accepts_a_message_override():
    err = api_error(ErrorCode.VALIDATION_FAILED, message="Body must be shorter.")
    assert err.detail["message"] == "Body must be shorter."


def test_api_error_attaches_a_field():
    err = api_error(ErrorCode.USERNAME_TAKEN, field="username")
    assert err.detail["data"]["field"] == "username"


def test_api_error_attaches_extra_context():
    err = api_error(ErrorCode.RATE_LIMITED, extra={"retry_after_seconds": 30})
    assert err.detail["data"]["retry_after_seconds"] == 30


def test_every_code_has_a_status_and_a_message():
    for code in ErrorCode:
        err = api_error(code)
        assert 400 <= err.status_code <= 599
        assert err.detail["message"].strip()


def test_invalid_credentials_does_not_distinguish_username_from_password():
    message = api_error(ErrorCode.INVALID_CREDENTIALS).detail["message"].lower()
    assert "username" not in message or "password" not in message


def test_not_found_and_not_permitted_share_one_code():
    assert api_error(ErrorCode.STORY_NOT_FOUND).status_code == 404


def test_error_code_values_are_screaming_snake_case():
    for code in ErrorCode:
        assert code.value == code.value.upper()


@pytest.mark.parametrize(
    ("code", "status"),
    [
        (ErrorCode.SESSION_REQUIRED, 401),
        (ErrorCode.TOKEN_EXPIRED, 401),
        (ErrorCode.TOKEN_REUSED, 401),
        (ErrorCode.ACCOUNT_BLOCKED, 403),
        (ErrorCode.REFERRAL_CODE_INVALID, 422),
        (ErrorCode.RATE_LIMITED, 429),
        (ErrorCode.SERVICE_UNAVAILABLE, 503),
    ],
)
def test_documented_status_mapping(code, status):
    assert api_error(code).status_code == status
