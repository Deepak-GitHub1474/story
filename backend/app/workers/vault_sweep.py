"""Vault uploads that were started and never finished.

`create_item` hands out an upload URL before any bytes move, and nothing
obliges the client to come back and complete. Bytes uploaded to that URL and
then abandoned belong to no finished item, so the quota never counts them —
which is the one way left for a single account to fill the disk.

The reservation itself is not harmless either: it spends the owner's quota for
as long as it lives, so a stack of dead reservations would lock a person out of
their own vault.
"""

from datetime import timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.time import utc_now
from app.logging import get_logger
from app.ports.storage import StoragePort

logger = get_logger("story.workers.vault_sweep")

VAULT_ITEMS = "vault_items"
PROFILE = "vault"
SWEEP_BATCH = 200


async def sweep_abandoned_uploads(
    *, mongo: AsyncIOMotorDatabase, storage: StoragePort, grace_seconds: int
) -> int:
    """Erase the bytes behind unfinished reservations, and close the rows.

    The grace period must outlast a presigned URL, or an upload still in flight
    would have its bytes pulled out from under it.
    """
    cutoff = utc_now() - timedelta(seconds=grace_seconds)
    stale: list[dict[str, Any]] = (
        await mongo[VAULT_ITEMS]
        .find(
            {"status": "pending", "deleted_at": None, "created_at": {"$lt": cutoff}},
            {"object_key": 1},
        )
        .limit(SWEEP_BATCH)
        .to_list(length=SWEEP_BATCH)
    )
    if not stale:
        return 0

    now = utc_now()
    for item in stale:
        await storage.delete(profile=PROFILE, key=item["object_key"])
        await mongo[VAULT_ITEMS].update_one(
            {"_id": item["_id"]},
            {"$set": {"deleted_at": now, "status": "abandoned", "label_hash": None}},
        )

    logger.info("vault_uploads_swept", service="storage", count=len(stale))
    return len(stale)
