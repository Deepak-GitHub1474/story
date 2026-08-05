from urllib.parse import urlparse

import httpx

from app.core.sigv4 import presign
from app.logging import get_logger

logger = get_logger("story.storage.s3")

DOWNLOAD_HEADERS = {
    "response-cache-control": "private, no-store",
    "response-content-type": "application/octet-stream",
}


class S3Adapter:
    def __init__(
        self,
        *,
        access_key: str,
        secret_key: str,
        region: str,
        endpoint: str,
        buckets: dict[str, str],
        session_token: str | None = None,
    ) -> None:
        if not buckets:
            raise ValueError("At least one storage profile must map to a bucket.")

        parsed = urlparse(endpoint)
        if not parsed.hostname:
            raise ValueError(f"Storage endpoint is not a URL: {endpoint}")

        self._access_key = access_key
        self._secret_key = secret_key
        self._region = region
        self._session_token = session_token
        self._scheme = parsed.scheme or "https"
        self._host = parsed.netloc
        self._buckets = buckets

    def key_for(self, *, owner_id: str, item_id: str) -> str:
        return f"vault/{owner_id}/{item_id}"

    def _path(self, profile: str, key: str) -> str:
        bucket = self._buckets.get(profile)
        if bucket is None:
            raise ValueError(f"No bucket is configured for the {profile} profile.")
        return f"/{bucket}/{key.lstrip('/')}"

    def _url(
        self,
        profile: str,
        key: str,
        method: str,
        expires_in: int,
        extra_params: dict[str, str] | None = None,
    ) -> str:
        return presign(
            access_key=self._access_key,
            secret_key=self._secret_key,
            region=self._region,
            service="s3",
            host=self._host,
            method=method,
            path=self._path(profile, key),
            expires_in=expires_in,
            session_token=self._session_token,
            scheme=self._scheme,
            extra_params=extra_params,
        )

    async def presign_put(self, *, profile: str, key: str, expires_in: int) -> str:
        return self._url(profile, key, "PUT", expires_in)

    async def presign_get(self, *, profile: str, key: str, expires_in: int) -> str:
        return self._url(profile, key, "GET", expires_in, DOWNLOAD_HEADERS)

    async def head(self, *, profile: str, key: str) -> int | None:
        url = self._url(profile, key, "HEAD", 60)
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.head(url)

        if response.status_code == 404:
            return None
        if response.status_code >= 400:
            logger.error(
                "storage_head_failed", code="storage_head_failed", status=response.status_code
            )
            return None
        return int(response.headers.get("content-length", 0))

    async def delete(self, *, profile: str, key: str) -> None:
        url = self._url(profile, key, "DELETE", 60)
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.delete(url)

        if response.status_code >= 400 and response.status_code != 404:
            logger.error(
                "storage_delete_failed",
                code="storage_delete_failed",
                status=response.status_code,
            )
