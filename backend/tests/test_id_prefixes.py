import re
from pathlib import Path

from app.core.ids import ID_PREFIXES

SOURCE = Path(__file__).resolve().parent.parent / "app"


def prefixes_in_code() -> dict[str, str]:
    found = {}
    for file in SOURCE.rglob("*.py"):
        text = file.read_text()
        for match in re.finditer(r'new_id\(\s*["\']([a-z]+)["\']', text):
            line = text[: match.start()].count("\n") + 1
            found.setdefault(match.group(1), f"{file.name}:{line}")
    return found


def test_every_prefix_the_code_uses_is_registered():
    unregistered = {
        prefix: where
        for prefix, where in prefixes_in_code().items()
        if prefix not in ID_PREFIXES
    }

    assert not unregistered, (
        "new_id() raises at runtime for an unregistered prefix, and it only "
        f"raises on the request that needs it: {unregistered}"
    )
