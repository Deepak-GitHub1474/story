import json

from app.logging import build_error_log, redact


def test_error_log_records_when_it_happened():
    entry = build_error_log(message="boom", route="/v1/auth/signin", method="POST", status=500)
    assert entry["time"].endswith("Z")


def test_error_log_records_the_error_message():
    entry = build_error_log(message="boom", route="/v1/auth/signin", method="POST", status=500)
    assert entry["error"] == "boom"


def test_error_log_records_the_route_that_produced_it():
    entry = build_error_log(message="boom", route="/v1/auth/signin", method="POST", status=500)
    assert entry["route"] == "/v1/auth/signin"
    assert entry["method"] == "POST"


def test_error_log_records_the_status_and_code():
    entry = build_error_log(
        message="taken", route="/v1/auth/signup", method="POST", status=409, code="USERNAME_TAKEN"
    )
    assert entry["status"] == 409
    assert entry["code"] == "USERNAME_TAKEN"


def test_error_log_carries_the_request_id_so_a_report_maps_to_one_request():
    entry = build_error_log(
        message="boom", route="/v1/x", method="GET", status=500, request_id="req_abc"
    )
    assert entry["request_id"] == "req_abc"


def test_error_log_includes_the_source_location_when_given():
    entry = build_error_log(
        message="boom", route="/v1/x", method="GET", status=500, where="controllers.py:88"
    )
    assert entry["where"] == "controllers.py:88"


def test_error_log_is_json_serializable():
    entry = build_error_log(message="boom", route="/v1/x", method="GET", status=500)
    assert json.loads(json.dumps(entry))["error"] == "boom"


def test_redact_removes_a_password_value():
    assert redact({"username": "deepak", "password": "hunter2"})["password"] == "<redacted>"


def test_redact_keeps_allowlisted_keys():
    assert redact({"username": "deepak", "password": "x"})["username"] == "deepak"


def test_redact_is_case_insensitive():
    assert redact({"Password": "hunter2"})["Password"] == "<redacted>"


def test_redact_matches_denied_substrings():
    out = redact({"refresh_token": "abc", "wrapped_umk": "def", "otp_code": "123456"})
    assert set(out.values()) == {"<redacted>"}


def test_redact_recurses_into_nested_dicts():
    out = redact({"body": {"password": "hunter2"}})
    assert out["body"]["password"] == "<redacted>"


def test_redact_recurses_into_lists_of_dicts():
    out = redact({"items": [{"passcode": "1234"}]})
    assert out["items"][0]["passcode"] == "<redacted>"


def test_redact_denies_unknown_keys_by_default():
    assert redact({"some_new_field": "value"})["some_new_field"] == "<redacted>"


def test_no_denied_value_survives_a_full_payload():
    payload = {
        "username": "deepak",
        "password": "hunter2",
        "passcode": "112233",
        "otp": "445566",
        "refresh_token": "rt-secret",
        "authorization": "Bearer abc",
        "wrapped_umk": "umk-secret",
        "wrapped_dek": "dek-secret",
        "salt_pw": "salt-secret",
        "email": "a@b.com",
        "label_hash": "lh-secret",
    }
    dumped = json.dumps(redact(payload))
    for secret in (
        "hunter2",
        "112233",
        "445566",
        "rt-secret",
        "Bearer abc",
        "umk-secret",
        "dek-secret",
        "salt-secret",
        "a@b.com",
        "lh-secret",
    ):
        assert secret not in dumped
