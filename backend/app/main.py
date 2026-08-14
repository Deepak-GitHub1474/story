import asyncio
from contextlib import asynccontextmanager, suppress

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.config import get_settings
from app.db.backfill import backfill_likers
from app.db.indexes import ensure_indexes
from app.db.mongo import connect_mongo, disconnect_mongo
from app.db.redis import connect_redis, disconnect_redis
from app.db.seed import seed_reference_data
from app.error_handlers import register_exception_handlers
from app.logging import configure_logging, get_logger
from app.middleware import RequestContextMiddleware
from app.realtime import bus
from app.workers import scheduler

settings = get_settings()
configure_logging(env=settings.API_ENV, level=settings.LOG_LEVEL)
logger = get_logger("story.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_mongo(app, settings)
    await connect_redis(app, settings)

    if settings.ENSURE_INDEXES_ON_BOOT:
        applied = await ensure_indexes(app.state.mongo_db)
        logger.info("startup_indexes", count=sum(applied.values()))

    seeded = await seed_reference_data(app.state.mongo_db)
    logger.info("startup_seed", count=sum(seeded.values()))

    app.state.likers_backfill = asyncio.create_task(backfill_likers(app.state.mongo_db))

    if settings.RUN_BACKGROUND_JOBS:
        scheduler.start(app, app.state.mongo_db)

    app.state.realtime_bus = asyncio.create_task(bus.listen(app.state.redis))

    logger.info(
        "startup_complete",
        service=settings.APP_NAME,
        env=settings.API_ENV,
        version=settings.APP_VERSION,
    )
    try:
        yield
    finally:
        listener = getattr(app.state, "realtime_bus", None)
        if listener is not None:
            listener.cancel()
            with suppress(asyncio.CancelledError):
                await listener

        backfill = getattr(app.state, "likers_backfill", None)
        if backfill is not None:
            backfill.cancel()
            with suppress(asyncio.CancelledError):
                await backfill

        await scheduler.stop(app)
        for name, close in (("redis", disconnect_redis), ("mongodb", disconnect_mongo)):
            try:
                await close(app)
            except Exception as exc:
                logger.error(
                    "shutdown_failed",
                    service=name,
                    error=f"{type(exc).__name__}: {exc}",
                )


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs" if settings.API_ENV != "production" else None,
    redoc_url=None,
)

register_exception_handlers(app)
app.include_router(api_router, prefix=settings.API_PREFIX)
app.add_middleware(RequestContextMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "content-type",
        "authorization",
        "x-csrf-token",
        "x-client-version",
        "x-request-id",
        "idempotency-key",
    ],
)
