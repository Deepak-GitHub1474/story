from fastapi import APIRouter, Request, status
from fastapi.responses import JSONResponse

from app.core.deps import AppSettings
from app.db.mongo import ping_mongo
from app.db.redis import ping_redis
from app.responses import err_payload, ok_response

router = APIRouter(tags=["health"])


@router.get("/health", status_code=status.HTTP_200_OK)
async def health(settings: AppSettings):
    return ok_response(
        "Service is running.",
        data={
            "service": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "env": settings.API_ENV,
        },
    )


@router.get("/health/ready")
async def ready(request: Request):
    mongo_ok = await ping_mongo(request.app)
    redis_ok = await ping_redis(request.app)
    dependencies = {"mongodb": mongo_ok, "redis": redis_ok}

    if mongo_ok and redis_ok:
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=ok_response("Ready to serve traffic.", data=dependencies),
        )

    down = [name for name, up in dependencies.items() if not up]
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=err_payload(
            "Something we depend on is unavailable.",
            code="SERVICE_UNAVAILABLE",
            extra={"service": down[0], "dependencies": dependencies},
        ),
    )
