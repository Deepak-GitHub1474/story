import asyncio
import smtplib
from collections.abc import Callable
from email.message import EmailMessage
from typing import Any

from app.logging import get_logger

logger = get_logger("story.mail.smtp")

SUBJECTS = {
    "password_reset": "Story — your password reset code",
    "verify_email": "Story — confirm this address",
    "recovery": "Story — your recovery code",
}
DEFAULT_SUBJECT = "Story — your code"

BODY = """{intro}

    {otp}

The code lasts ten minutes and can be used once.

If this was not you, ignore this message. Nobody can act on it without
the code, and we will never ask you for it.
"""

INTROS = {
    "password_reset": "Someone asked to reset the password on your Story account.",
    "verify_email": "Confirm this address so your Story account can be recovered.",
}
DEFAULT_INTRO = "Here is the code you asked for."


class _BlockingSmtp:
    def __init__(self, *, host: str, port: int, use_tls: bool) -> None:
        self._host = host
        self._port = port
        self._use_tls = use_tls
        self._client: smtplib.SMTP | None = None

    async def __aenter__(self):
        self._client = await asyncio.to_thread(
            smtplib.SMTP, self._host, self._port, timeout=15
        )
        return self

    async def __aexit__(self, *_) -> bool:
        if self._client is not None:
            await asyncio.to_thread(self._client.quit)
        return False

    async def starttls(self) -> None:
        if self._use_tls and self._client is not None:
            await asyncio.to_thread(self._client.starttls)

    async def login(self, username: str, password: str) -> None:
        if username and self._client is not None:
            await asyncio.to_thread(self._client.login, username, password)

    async def send(self, message: EmailMessage) -> None:
        if self._client is not None:
            await asyncio.to_thread(self._client.send_message, message)


class SmtpMailAdapter:
    def __init__(
        self,
        *,
        host: str,
        port: int,
        username: str,
        password: str,
        from_address: str,
        use_tls: bool = True,
        transport: Callable[..., Any] | None = None,
    ) -> None:
        self._host = host
        self._port = port
        self._username = username
        self._password = password
        self._from = from_address
        self._use_tls = use_tls
        self._transport = transport or (
            lambda **kwargs: _BlockingSmtp(
                host=kwargs["host"], port=kwargs["port"], use_tls=kwargs["use_tls"]
            )
        )

    def _message(self, *, to: str, subject: str, body: str) -> EmailMessage:
        message = EmailMessage()
        message["From"] = self._from
        message["To"] = to
        message["Subject"] = subject
        message.set_content(body)
        return message

    async def _deliver(self, message: EmailMessage, *, code: str) -> None:
        try:
            client = self._transport(
                host=self._host, port=self._port, use_tls=self._use_tls
            )
            async with client as session:
                await session.starttls()
                await session.login(self._username, self._password)
                await session.send(message)
            logger.info("mail_sent", service="smtp", code=code)
        except Exception:
            logger.error("mail_send_failed", service="smtp", code=code)

    async def send_otp(self, *, email: str, otp: str, purpose: str) -> None:
        await self._deliver(
            self._message(
                to=email,
                subject=SUBJECTS.get(purpose, DEFAULT_SUBJECT),
                body=BODY.format(intro=INTROS.get(purpose, DEFAULT_INTRO), otp=otp),
            ),
            code=purpose,
        )

    async def send_security_alert(self, *, email: str, subject: str, body: str) -> None:
        await self._deliver(
            self._message(to=email, subject=subject, body=body),
            code="security_alert",
        )
