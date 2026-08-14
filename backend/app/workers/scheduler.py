import asyncio
import contextlib

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.config import get_settings
from app.logging import get_logger
from app.ports.factory import build_storage
from app.workers.deletion import purge_deleted_accounts
from app.workers.maintenance import publish_scheduled_stories, reconcile_counts

logger = get_logger("story.workers.scheduler")

PUBLISH_INTERVAL_SECONDS = 60
RECONCILE_INTERVAL_SECONDS = 3600
PURGE_INTERVAL_SECONDS = 3600


async def _every(seconds: int, job, mongo: AsyncIOMotorDatabase, name: str) -> None:
    while True:
        await asyncio.sleep(seconds)
        try:
            await job(mongo)
        except Exception as exc:
            logger.error("job_failed", service=name, error=f"{type(exc).__name__}: {exc}")


async def _purge(mongo: AsyncIOMotorDatabase) -> int:
    return await purge_deleted_accounts(mongo, storage=build_storage(get_settings()))


def start(app, mongo: AsyncIOMotorDatabase) -> None:
    app.state.background_jobs = [
        asyncio.create_task(
            _every(PUBLISH_INTERVAL_SECONDS, publish_scheduled_stories, mongo, "publish")
        ),
        asyncio.create_task(
            _every(RECONCILE_INTERVAL_SECONDS, reconcile_counts, mongo, "reconcile")
        ),
        asyncio.create_task(_every(PURGE_INTERVAL_SECONDS, _purge, mongo, "purge")),
    ]
    logger.info("scheduler_started", count=len(app.state.background_jobs))


async def stop(app) -> None:
    for task in getattr(app.state, "background_jobs", []):
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
    app.state.background_jobs = []
