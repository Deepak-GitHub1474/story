import asyncio
import hashlib
import json
import time

import httpx
import jwt

from app.logging import get_logger
from app.ports.push import PushMessage, PushOutcome

logger = get_logger("story.push.fcm")

OAUTH_URL = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
GRANT = "urn:ietf:params:oauth:grant-type:jwt-bearer"
SEND_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"

TOKEN_LIFETIME_SECONDS = 3600
TOKEN_REFRESH_MARGIN_SECONDS = 120
MAX_IN_FLIGHT = 10

DEAD_TOKEN_STATUSES = (404,)
DEAD_TOKEN_CODES = ("UNREGISTERED", "SENDER_ID_MISMATCH")
DEAD_DEVICE_PHRASE = "registration token"
RETRY_STATUSES = (429, 500, 502, 503, 504)
COLLAPSE_MAX_BYTES = 64
COLLAPSE_HASH_CHARS = 32


def collapse_id(thread: str) -> str:
    if len(thread.encode()) <= COLLAPSE_MAX_BYTES:
        return thread
    return hashlib.sha256(thread.encode()).hexdigest()[:COLLAPSE_HASH_CHARS]


def classify(status_code: int, detail_status: str, detail_message: str) -> str:
    if status_code == 200:
        return "delivered"
    if status_code in RETRY_STATUSES:
        return "retry"
    if status_code in DEAD_TOKEN_STATUSES:
        return "stale"
    if detail_status in DEAD_TOKEN_CODES:
        return "stale"
    if detail_status == "INVALID_ARGUMENT" and DEAD_DEVICE_PHRASE in detail_message:
        return "stale"
    return "retry"


class FcmConfigError(ValueError):
    pass


def read_service_account(raw: str) -> dict[str, str]:
    try:
        account = json.loads(raw)
    except ValueError as exc:
        raise FcmConfigError("FCM_SERVICE_ACCOUNT is not valid JSON") from exc

    missing = [k for k in ("project_id", "client_email", "private_key") if not account.get(k)]
    if missing:
        raise FcmConfigError(f"FCM_SERVICE_ACCOUNT is missing: {', '.join(missing)}")

    account["private_key"] = account["private_key"].replace("\\n", "\n")
    return account


class FcmAdapter:
    def __init__(self, *, service_account: dict[str, str], timeout: float = 10.0) -> None:
        self._account = service_account
        self._timeout = timeout
        self._token = ""
        self._token_expires_at = 0.0
        self._lock = asyncio.Lock()

    @property
    def is_available(self) -> bool:
        return bool(self._account.get("private_key"))

    @property
    def project_id(self) -> str:
        return self._account["project_id"]

    async def _access_token(self, client: httpx.AsyncClient) -> str:
        async with self._lock:
            if self._token and time.time() < self._token_expires_at:
                return self._token

            issued = int(time.time())
            assertion = jwt.encode(
                {
                    "iss": self._account["client_email"],
                    "scope": SCOPE,
                    "aud": OAUTH_URL,
                    "iat": issued,
                    "exp": issued + TOKEN_LIFETIME_SECONDS,
                },
                self._account["private_key"],
                algorithm="RS256",
            )
            response = await client.post(
                OAUTH_URL, data={"grant_type": GRANT, "assertion": assertion}
            )
            response.raise_for_status()
            payload = response.json()

            self._token = payload["access_token"]
            lifetime = int(payload.get("expires_in", TOKEN_LIFETIME_SECONDS))
            self._token_expires_at = time.time() + lifetime - TOKEN_REFRESH_MARGIN_SECONDS
            return self._token

    def _envelope(self, message: PushMessage) -> dict:
        thread = collapse_id(message.data.get("thread", ""))
        return {
            "message": {
                "token": message.token,
                "notification": {"title": message.title, "body": message.body},
                "data": message.data,
                "android": {
                    "priority": "high",
                    "notification": {
                        "icon": "ic_notification",
                        "tag": thread,
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    },
                },
                "apns": {
                    "headers": {
                        "apns-priority": "10",
                        "apns-collapse-id": thread,
                    }
                },
            }
        }

    async def _send_one(
        self, client: httpx.AsyncClient, token: str, message: PushMessage, gate: asyncio.Semaphore
    ) -> tuple[str, str]:
        async with gate:
            try:
                response = await client.post(
                    SEND_URL.format(project=self.project_id),
                    headers={"Authorization": f"Bearer {token}"},
                    json=self._envelope(message),
                )
            except httpx.HTTPError as exc:
                logger.warning("push_send_failed", error=f"{type(exc).__name__}: {exc}")
                return ("retry", message.token)

            status, detail = "", ""
            if response.status_code != 200:
                try:
                    error = response.json().get("error", {})
                    status, detail = error.get("status", ""), error.get("message", "")
                except ValueError:
                    detail = response.text[:200]

            verdict = classify(response.status_code, status, detail)
            if verdict == "retry" and response.status_code not in RETRY_STATUSES:
                logger.error(
                    "push_rejected",
                    code=str(response.status_code),
                    error=f"{status}: {detail[:160]}",
                )
            return (verdict, message.token)

    async def send(self, messages: list[PushMessage]) -> PushOutcome:
        if not messages:
            return PushOutcome()

        gate = asyncio.Semaphore(MAX_IN_FLIGHT)
        buckets: dict[str, list[str]] = {"delivered": [], "stale": [], "retry": []}

        async with httpx.AsyncClient(timeout=self._timeout) as client:
            try:
                token = await self._access_token(client)
            except (httpx.HTTPError, KeyError, ValueError) as exc:
                logger.error("push_auth_failed", error=f"{type(exc).__name__}: {exc}")
                return PushOutcome(retry=tuple(m.token for m in messages))

            results = await asyncio.gather(
                *(self._send_one(client, token, m, gate) for m in messages),
                return_exceptions=True,
            )

        for message, result in zip(messages, results, strict=True):
            if isinstance(result, BaseException):
                buckets["retry"].append(message.token)
                continue
            outcome, value = result
            buckets[outcome].append(value)

        return PushOutcome(
            delivered=tuple(buckets["delivered"]),
            stale=tuple(buckets["stale"]),
            retry=tuple(buckets["retry"]),
        )
