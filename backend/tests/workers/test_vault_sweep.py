"""Reservations that were never completed, and the bytes behind them.

An upload URL is handed out before any bytes move. Nothing forces the client to
come back and say it finished — so an account can upload to that URL and simply
never complete, leaving bytes on the disk that the quota never counted. This is
what collects them.
"""

from datetime import timedelta

import pytest
import pytest_asyncio

from app.core.time import utc_now
from app.workers.vault_sweep import sweep_abandoned_uploads

VAULT_ITEMS = "vault_items"
GRACE = 3600


class FakeStorage:
    """Storage that remembers what it holds and what was asked of it."""

    def __init__(self, held: dict[str, int] | None = None):
        self.held = dict(held or {})
        self.deleted: list[str] = []

    async def head(self, *, profile: str, key: str) -> int | None:
        return self.held.get(key)

    async def delete(self, *, profile: str, key: str) -> None:
        self.deleted.append(key)
        self.held.pop(key, None)


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


async def reserve(mongo, *, item_id, age_seconds, status="pending", size=2048):
    await mongo[VAULT_ITEMS].insert_one(
        {
            "_id": item_id,
            "user_id": "usr_hoarder",
            "kind": "image",
            "size_bytes": size,
            "object_key": f"vault/usr_hoarder/{item_id}",
            "status": status,
            "visibility": "normal",
            "created_at": utc_now() - timedelta(seconds=age_seconds),
            "deleted_at": None,
        }
    )
    return f"vault/usr_hoarder/{item_id}"


async def test_an_abandoned_upload_loses_its_bytes(mongo):
    key = await reserve(mongo, item_id="vit_ghost", age_seconds=GRACE * 2)
    storage = FakeStorage({key: 500 * 1024**2})

    swept = await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=GRACE)

    assert swept == 1
    assert storage.deleted == [key]
    assert storage.held == {}


async def test_an_abandoned_upload_stops_spending_quota(mongo):
    await reserve(mongo, item_id="vit_ghost", age_seconds=GRACE * 2)
    storage = FakeStorage({"vault/usr_hoarder/vit_ghost": 500 * 1024**2})

    await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=GRACE)

    item = await mongo[VAULT_ITEMS].find_one({"_id": "vit_ghost"})
    assert item["deleted_at"] is not None
    assert item["status"] == "abandoned"


async def test_a_reservation_still_inside_its_grace_is_left_alone(mongo):
    key = await reserve(mongo, item_id="vit_uploading", age_seconds=60)
    storage = FakeStorage({key: 2048})

    swept = await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=GRACE)

    assert swept == 0
    assert storage.deleted == []


async def test_a_finished_item_is_never_touched(mongo):
    key = await reserve(mongo, item_id="vit_real", age_seconds=GRACE * 10, status="ready")
    storage = FakeStorage({key: 2048})

    swept = await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=GRACE)

    assert swept == 0
    assert storage.held == {key: 2048}


async def test_a_reservation_nobody_uploaded_to_is_closed_anyway(mongo):
    """No bytes to erase, but the row still spends quota until it is closed."""
    await reserve(mongo, item_id="vit_empty", age_seconds=GRACE * 2)
    storage = FakeStorage()

    swept = await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=GRACE)

    item = await mongo[VAULT_ITEMS].find_one({"_id": "vit_empty"})
    assert swept == 1
    assert item["deleted_at"] is not None


async def test_the_sweep_costs_nothing_when_there_is_nothing_to_do(mongo):
    storage = FakeStorage()

    assert await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=GRACE) == 0


@pytest.mark.parametrize("grace", [900, 7200])
async def test_the_grace_period_decides_what_counts_as_abandoned(mongo, grace):
    await reserve(mongo, item_id="vit_edge", age_seconds=3600)
    storage = FakeStorage({"vault/usr_hoarder/vit_edge": 4096})

    swept = await sweep_abandoned_uploads(mongo=mongo, storage=storage, grace_seconds=grace)

    assert swept == (1 if grace < 3600 else 0)


async def test_the_scheduler_actually_runs_the_sweep(mongo, app_instance):
    """A sweeper nothing calls is a sweeper that does not exist."""
    from app.workers import scheduler

    await reserve(mongo, item_id="vit_wired", age_seconds=10 * 3600)

    assert "vault_sweep" in [name for _, _, name in scheduler.jobs(app_instance)]
    assert await scheduler._sweep_vault(mongo) == 1
