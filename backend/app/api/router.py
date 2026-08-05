from fastapi import APIRouter

from app.api.endpoints.auth.router import router as auth_router
from app.api.endpoints.health.router import router as health_router
from app.api.endpoints.interests.router import router as interests_router
from app.api.endpoints.stories.router import router as stories_router
from app.api.endpoints.users.router import router as users_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(stories_router)
api_router.include_router(interests_router)
