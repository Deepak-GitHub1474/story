import hashlib
import hmac
import pathlib
import time

from app.logging import get_logger

logger = get_logger("story.storage.local")


class LocalDiskAdapter:
    def __init__(self, *, root: str, base_url: str, secret: str) -> None:
        self._root = pathlib.Path(root)
        self._base_url = base_url.rstrip("/")
        self._secret = secret.encode()
        self._root.mkdir(parents=True, exist_ok=True)

    def key_for(self, *, owner_id: str, item_id: str) -> str:
        return f"vault/{owner_id}/{item_id}"

    def _path(self, profile: str, key: str) -> pathlib.Path:
        safe = key.replace("..", "").lstrip("/")
        return self._root / profile / safe

    def _sign(self, profile: str, key: str, method: str, expires: int) -> str:
        payload = f"{method}|{profile}|{key}|{expires}".encode()
        return hmac.new(self._secret, payload, hashlib.sha256).hexdigest()

    def _url(self, profile: str, key: str, method: str, expires_in: int) -> str:
        expires = int(time.time()) + expires_in
        signature = self._sign(profile, key, method, expires)
        return f"{self._base_url}/{profile}/{key}?expires={expires}&signature={signature}"

    def verify(self, profile: str, key: str, method: str, expires: int, signature: str) -> bool:
        if expires < int(time.time()):
            return False
        return hmac.compare_digest(self._sign(profile, key, method, expires), signature)

    async def presign_put(self, *, profile: str, key: str, expires_in: int) -> str:
        return self._url(profile, key, "PUT", expires_in)

    async def presign_get(self, *, profile: str, key: str, expires_in: int) -> str:
        return self._url(profile, key, "GET", expires_in)

    async def head(self, *, profile: str, key: str) -> int | None:
        path = self._path(profile, key)
        return path.stat().st_size if path.exists() else None

    async def delete(self, *, profile: str, key: str) -> None:
        path = self._path(profile, key)
        if path.exists():
            path.unlink()

    async def write(self, *, profile: str, key: str, payload: bytes) -> int:
        path = self._path(profile, key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
        return len(payload)

    async def read(self, *, profile: str, key: str) -> bytes | None:
        path = self._path(profile, key)
        return path.read_bytes() if path.exists() else None
