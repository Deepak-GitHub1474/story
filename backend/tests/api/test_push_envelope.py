from app.adapters.push_fcm import COLLAPSE_MAX_BYTES, FcmAdapter, classify
from app.ports.push import PushMessage

LONG_THREAD = "chat_message:usr_01M0A10Y8MWQ371V5KN86MY10T:cnv_01KZNC2XBTD3F1259XT4TQP8WW"


def an_adapter():
    return FcmAdapter(
        service_account={"project_id": "p", "client_email": "e", "private_key": "k"}
    )


def test_a_long_thread_is_shortened_for_apple():
    message = PushMessage(token="t", title="T", body="B", data={"thread": LONG_THREAD})

    envelope = an_adapter()._envelope(message)
    collapse = envelope["message"]["apns"]["headers"]["apns-collapse-id"]

    assert len(LONG_THREAD.encode()) > COLLAPSE_MAX_BYTES, "this thread is the real one that failed"
    assert len(collapse.encode()) <= COLLAPSE_MAX_BYTES, (
        "FCM rejects the whole send with INVALID_ARGUMENT past 64 bytes"
    )


def test_the_same_thread_always_collapses_the_same_way():
    first = an_adapter()._envelope(
        PushMessage(token="t", title="T", body="B", data={"thread": LONG_THREAD})
    )
    second = an_adapter()._envelope(
        PushMessage(token="t", title="T", body="B", data={"thread": LONG_THREAD})
    )

    assert (
        first["message"]["apns"]["headers"]["apns-collapse-id"]
        == second["message"]["apns"]["headers"]["apns-collapse-id"]
    ), "an unstable id would stop replacing the older notification"


def test_a_short_thread_is_left_alone():
    envelope = an_adapter()._envelope(
        PushMessage(token="t", title="T", body="B", data={"thread": "story_like:a:b"})
    )

    assert envelope["message"]["apns"]["headers"]["apns-collapse-id"] == "story_like:a:b"


def test_a_dead_token_is_stale():
    assert classify(404, "", "") == "stale"
    assert classify(400, "UNREGISTERED", "") == "stale"
    dead = "The registration token is not a valid FCM registration token"
    assert classify(400, "INVALID_ARGUMENT", dead) == "stale"


def test_our_own_malformed_request_never_deletes_a_token():
    verdict = classify(
        400,
        "INVALID_ARGUMENT",
        "The length of [apns-collapse-id] header must not exceed [64] bytes.",
    )

    assert verdict != "stale", (
        "a bug in the payload must not erase a phone that is perfectly reachable"
    )
    assert verdict == "retry"


def test_a_wobbly_server_is_retried():
    for code in (429, 500, 503):
        assert classify(code, "", "") == "retry"


def test_success_is_success():
    assert classify(200, "", "") == "delivered"


def test_the_tap_uses_the_normal_launcher():
    envelope = an_adapter()._envelope(
        PushMessage(token="t", title="T", body="B", data={"thread": "x"})
    )
    android = envelope["message"]["android"]["notification"]

    assert "click_action" not in android, (
        "FLUTTER_NOTIFICATION_CLICK needs a matching intent-filter; without one "
        "Android cannot resolve the tap and the app either stays shut or opens "
        "with no payload to route on"
    )


def test_the_notification_still_says_which_icon_and_thread():
    android = an_adapter()._envelope(
        PushMessage(token="t", title="T", body="B", data={"thread": "abc"})
    )["message"]["android"]["notification"]

    assert android["icon"] == "ic_notification"
    assert android["tag"] == "abc"
