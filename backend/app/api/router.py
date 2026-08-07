from fastapi import APIRouter

from app.api.endpoints.admin.router import router as admin_router
from app.api.endpoints.admin.vault_router import router as admin_vault_router
from app.api.endpoints.auth.router import router as auth_router
from app.api.endpoints.chat.router import router as chat_router
from app.api.endpoints.communities.router import router as communities_router
from app.api.endpoints.connections.router import router as connections_router
from app.api.endpoints.email.router import router as email_router
from app.api.endpoints.health.router import router as health_router
from app.api.endpoints.interests.router import router as interests_router
from app.api.endpoints.notifications.router import router as notifications_router
from app.api.endpoints.public.router import router as public_router
from app.api.endpoints.realtime.router import router as realtime_router
from app.api.endpoints.reports.router import router as reports_router
from app.api.endpoints.search.router import router as search_router
from app.api.endpoints.stories.router import router as stories_router
from app.api.endpoints.tickets.router import router as tickets_router
from app.api.endpoints.totp.router import router as totp_router
from app.api.endpoints.users.router import router as users_router
from app.api.endpoints.vault.router import router as vault_router
from app.api.endpoints.vault.storage_router import router as storage_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(admin_router)
api_router.include_router(admin_vault_router)
api_router.include_router(chat_router)
api_router.include_router(realtime_router)
api_router.include_router(tickets_router)
api_router.include_router(totp_router)
api_router.include_router(email_router)
api_router.include_router(users_router)
api_router.include_router(vault_router)
api_router.include_router(storage_router)
api_router.include_router(stories_router)
api_router.include_router(communities_router)
api_router.include_router(connections_router)
api_router.include_router(notifications_router)
api_router.include_router(public_router)
api_router.include_router(reports_router)
api_router.include_router(search_router)
api_router.include_router(interests_router)
