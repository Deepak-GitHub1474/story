from datetime import UTC, datetime

MICROSECONDS_PER_MILLISECOND = 1000


def utc_now() -> datetime:
    return to_storage(datetime.now(UTC))


def to_storage(value: datetime) -> datetime:
    if value.tzinfo is None:
        raise ValueError("Naive datetime rejected; supply a timezone-aware value.")
    aware = value.astimezone(UTC)
    return aware.replace(
        microsecond=(aware.microsecond // MICROSECONDS_PER_MILLISECOND)
        * MICROSECONDS_PER_MILLISECOND
    )


def from_wire(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return to_storage(parsed)


def to_wire(value: datetime | None) -> str | None:
    if value is None:
        return None
    return to_storage(value).isoformat(timespec="milliseconds").replace("+00:00", "Z")
