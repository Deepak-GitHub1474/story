from fastapi import APIRouter

from app.api.endpoints.auth.router import router as auth_router
from app.api.endpoints.communities.router import router as communities_router
from app.api.endpoints.connections.router import router as connections_router
from app.api.endpoints.health.router import router as health_router
from app.api.endpoints.interests.router import router as interests_router
from app.api.endpoints.notifications.router import router as notifications_router
from app.api.endpoints.search.router import router as search_router
from app.api.endpoints.stories.router import router as stories_router
from app.api.endpoints.users.router import router as users_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(stories_router)
api_router.include_router(communities_router)
api_router.include_router(connections_router)
api_router.include_router(notifications_router)
api_router.include_router(search_router)
api_router.include_router(interests_router)
