from datetime import UTC, datetime, timedelta, timezone

import pytest

from app.core.time import to_storage, to_wire


def test_to_storage_rejects_naive_datetime():
    with pytest.raises(ValueError, match="Naive datetime"):
        to_storage(datetime(2026, 8, 5, 11, 14, 32))


def test_to_storage_converts_other_zones_to_utc():
    ist = timezone(timedelta(hours=5, minutes=30))
    value = datetime(2026, 8, 5, 16, 44, 32, tzinfo=ist)
    assert to_storage(value) == datetime(2026, 8, 5, 11, 14, 32, tzinfo=UTC)


def test_to_storage_truncates_microseconds_to_milliseconds():
    value = datetime(2026, 8, 5, 11, 14, 32, 987_654, tzinfo=UTC)
    assert to_storage(value).microsecond == 987_000


def test_to_wire_emits_iso8601_utc_with_z_suffix_and_millisecond_precision():
    value = datetime(2026, 8, 5, 11, 14, 32, 500_000, tzinfo=UTC)
    assert to_wire(value) == "2026-08-05T11:14:32.500Z"


def test_to_wire_always_emits_three_decimal_places():
    value = datetime(2026, 8, 5, 11, 14, 32, tzinfo=UTC)
    assert to_wire(value) == "2026-08-05T11:14:32.000Z"


def test_to_wire_converts_non_utc_input():
    ist = timezone(timedelta(hours=5, minutes=30))
    value = datetime(2026, 8, 5, 16, 44, 32, tzinfo=ist)
    assert to_wire(value) == "2026-08-05T11:14:32.000Z"


def test_to_wire_passes_none_through():
    assert to_wire(None) is None
