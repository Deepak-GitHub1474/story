from fastapi import APIRouter

from app.api.endpoints.auth.router import router as auth_router
from app.api.endpoints.health.router import router as health_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
