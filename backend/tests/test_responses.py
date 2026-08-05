import pytest

from app.responses import err_payload, ok_response


def test_ok_response_has_exactly_the_three_envelope_keys():
    assert set(ok_response("Saved.").keys()) == {"success", "message", "data"}


def test_ok_response_keeps_data_present_as_null_when_there_is_no_payload():
    assert ok_response("Saved.")["data"] is None


def test_ok_response_marks_success():
    assert ok_response("Saved.")["success"] is True


def test_ok_response_carries_its_payload():
    assert ok_response("Saved.", data={"id": "usr_1"})["data"] == {"id": "usr_1"}


def test_ok_response_requires_a_terminal_punctuation_mark():
    with pytest.raises(ValueError, match="terminal punctuation"):
        ok_response("Saved")


def test_err_payload_has_exactly_the_three_envelope_keys():
    assert set(err_payload("Taken.", code="USERNAME_TAKEN").keys()) == {
        "success",
        "message",
        "data",
    }


def test_err_payload_marks_failure():
    assert err_payload("Taken.", code="USERNAME_TAKEN")["success"] is False


def test_err_payload_always_carries_a_code_for_clients_to_branch_on():
    assert err_payload("Taken.", code="USERNAME_TAKEN")["data"]["code"] == "USERNAME_TAKEN"


def test_err_payload_includes_the_offending_field_when_given():
    payload = err_payload("Taken.", code="USERNAME_TAKEN", field="username")
    assert payload["data"]["field"] == "username"


def test_err_payload_omits_the_field_key_entirely_when_not_given():
    assert "field" not in err_payload("Nope.", code="INTERNAL_ERROR")["data"]


def test_err_payload_merges_extra_context_into_data():
    payload = err_payload("Slow down.", code="RATE_LIMITED", extra={"retry_after_seconds": 30})
    assert payload["data"]["retry_after_seconds"] == 30


def test_err_payload_rejects_an_extra_key_that_would_shadow_the_code():
    with pytest.raises(ValueError, match="reserved"):
        err_payload("Nope.", code="INTERNAL_ERROR", extra={"code": "SOMETHING_ELSE"})


def test_err_payload_requires_a_terminal_punctuation_mark():
    with pytest.raises(ValueError, match="terminal punctuation"):
        err_payload("Taken", code="USERNAME_TAKEN")


def test_err_payload_requires_a_screaming_snake_case_code():
    with pytest.raises(ValueError, match="SCREAMING_SNAKE_CASE"):
        err_payload("Taken.", code="usernameTaken")
