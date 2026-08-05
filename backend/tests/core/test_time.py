from datetime import UTC, datetime

from app.core.time import utc_now


def test_utc_now_is_timezone_aware_utc():
    now = utc_now()
    assert now.tzinfo is not None
    assert now.utcoffset() == UTC.utcoffset(None)


def test_utc_now_is_truncated_to_milliseconds():
    for _ in range(50):
        assert utc_now().microsecond % 1000 == 0


def test_utc_now_is_close_to_real_time():
    assert abs((utc_now() - datetime.now(UTC)).total_seconds()) < 1
