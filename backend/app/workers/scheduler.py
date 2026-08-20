import asyncio
import contextlib
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.media.cleanup import sweep_orphans
from app.config import get_settings
from app.logging import get_logger
from app.ports.factory import build_push, build_storage
from app.workers.deletion import purge_deleted_accounts
from app.workers.maintenance import publish_scheduled_stories, reconcile_counts
from app.workers.push import sweep_due
from app.workers.vault_sweep import sweep_abandoned_uploads

logger = get_logger("story.workers.scheduler")

PUBLISH_INTERVAL_SECONDS = 60
RECONCILE_INTERVAL_SECONDS = 3600
PURGE_INTERVAL_SECONDS = 3600
MEDIA_SWEEP_INTERVAL_SECONDS = 3600
PUSH_SWEEP_INTERVAL_SECONDS = 30
VAULT_SWEEP_INTERVAL_SECONDS = 3600


async def _every(seconds: int, job, mongo: AsyncIOMotorDatabase, name: str) -> None:
    while True:
        await asyncio.sleep(seconds)
        try:
            await job(mongo)
        except Exception as exc:
            logger.error("job_failed", service=name, error=f"{type(exc).__name__}: {exc}")


async def _purge(mongo: AsyncIOMotorDatabase) -> int:
    return await purge_deleted_accounts(mongo, storage=build_storage(get_settings()))


async def _sweep_media(mongo: AsyncIOMotorDatabase) -> int:
    settings = get_settings()
    removed = await sweep_orphans(
        mongo=mongo,
        storage=build_storage(settings),
        grace_seconds=settings.MEDIA_ORPHAN_GRACE_SECONDS,
    )
    if removed:
        logger.info("media_swept", service="storage", count=removed)
    return removed


async def _sweep_vault(mongo: AsyncIOMotorDatabase) -> int:
    settings = get_settings()
    return await sweep_abandoned_uploads(
        mongo=mongo,
        storage=build_storage(settings),
        grace_seconds=settings.VAULT_UPLOAD_GRACE_SECONDS,
    )


def _push_sweeper(app):
    async def run(mongo: AsyncIOMotorDatabase) -> int:
        settings = get_settings()
        if settings.PUSH_PROVIDER == "none":
            return 0

        sent = await sweep_due(
            mongo=mongo,
            push=build_push(settings),
            redis=getattr(app.state, "redis", None),
            lease_seconds=settings.PUSH_LEASE_SECONDS,
            max_tries=settings.PUSH_MAX_TRIES,
        )
        if sent:
            logger.info("push_swept", service="push", count=sent)
        return sent

    return run


def jobs(app) -> list[tuple[int, Any, str]]:
    """Everything that runs on a timer, as data, so it can be read and tested."""
    return [
        (PUBLISH_INTERVAL_SECONDS, publish_scheduled_stories, "publish"),
        (RECONCILE_INTERVAL_SECONDS, reconcile_counts, "reconcile"),
        (PURGE_INTERVAL_SECONDS, _purge, "purge"),
        (MEDIA_SWEEP_INTERVAL_SECONDS, _sweep_media, "media_sweep"),
        (PUSH_SWEEP_INTERVAL_SECONDS, _push_sweeper(app), "push_sweep"),
        (VAULT_SWEEP_INTERVAL_SECONDS, _sweep_vault, "vault_sweep"),
    ]


def start(app, mongo: AsyncIOMotorDatabase) -> None:
    app.state.background_jobs = [
        asyncio.create_task(_every(seconds, job, mongo, name)) for seconds, job, name in jobs(app)
    ]
    logger.info("scheduler_started", count=len(app.state.background_jobs))


async def stop(app) -> None:
    for task in getattr(app.state, "background_jobs", []):
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
    app.state.background_jobs = []
