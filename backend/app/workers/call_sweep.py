from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.time import utc_now
from app.logging import get_logger

logger = get_logger("story.workers.call_sweep")

CALLS = "calls"


async def sweep_expired_calls(*, mongo: AsyncIOMotorDatabase) -> int:
    result = await mongo[CALLS].delete_many(
        {"expires_at": {"$type": "date", "$lt": utc_now()}}
    )
    if result.deleted_count:
        logger.info("calls_swept", service="calls", count=result.deleted_count)
    return result.deleted_count
