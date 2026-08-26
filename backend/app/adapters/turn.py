import base64
import hashlib
import hmac
from datetime import datetime, timedelta
from typing import Any

from app.config import Settings
from app.core.time import utc_now


def _relay_urls(settings: Settings) -> list[str]:
    return [url.strip() for url in settings.TURN_URLS.split(",") if url.strip()]


def ice_servers(
    user_id: str, *, settings: Settings, now: datetime | None = None
) -> list[dict[str, Any]]:
    servers: list[dict[str, Any]] = [{"urls": [settings.STUN_URL]}]

    urls = _relay_urls(settings)
    if not urls or not settings.TURN_SHARED_SECRET:
        return servers

    moment = now or utc_now()
    expiry = int((moment + timedelta(seconds=settings.TURN_CREDENTIAL_TTL_SECONDS)).timestamp())
    username = f"{expiry}:{user_id}"
    digest = hmac.new(
        settings.TURN_SHARED_SECRET.encode(), username.encode(), hashlib.sha1
    ).digest()

    servers.append(
        {
            "urls": urls,
            "username": username,
            "credential": base64.b64encode(digest).decode(),
        }
    )
    return servers
