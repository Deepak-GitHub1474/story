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

HTML_SHELL = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Story</title>
  </head>
  <body style="margin:0;padding:0;background:#FBFAF7;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
           style="background:#FBFAF7;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="max-width:520px;background:#FFFFFF;border:1px solid #E2DFD8;
                        border-radius:16px;overflow:hidden;">
            <tr>
              <td style="padding:28px 32px 8px 32px;
                         font-family:Georgia,'Iowan Old Style',serif;
                         letter-spacing:0.42em;font-size:12px;color:#8A867D;">
                STORY
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 0 32px;
                         font-family:-apple-system,'Segoe UI',sans-serif;
                         font-size:16px;line-height:1.7;color:#57544D;">
                {intro}
              </td>
            </tr>
            {body}
            <tr>
              <td style="padding:8px 32px 32px 32px;
                         font-family:-apple-system,'Segoe UI',sans-serif;
                         font-size:13px;line-height:1.7;color:#8A867D;">
                {footer}
              </td>
            </tr>
          </table>
          <div style="max-width:520px;padding:16px 8px;
                      font-family:-apple-system,'Segoe UI',sans-serif;
                      font-size:12px;line-height:1.6;color:#8A867D;text-align:center;">
            Story never asks for your password or your vault passcode, and nobody
            here can read what you keep in the vault.
          </div>
        </td>
      </tr>
    </table>
  </body>
</html>
"""

OTP_BLOCK = """<tr>
              <td style="padding:24px 32px 8px 32px;">
                <div style="font-family:'SF Mono',Menlo,Consolas,monospace;
                            font-size:32px;letter-spacing:0.24em;color:#1B1A17;
                            background:#F3F1EC;border-radius:12px;
                            padding:18px 12px;text-align:center;">
                  {otp}
                </div>
              </td>
            </tr>"""

TEXT_BLOCK = """<tr>
              <td style="padding:20px 32px 4px 32px;
                         font-family:-apple-system,'Segoe UI',sans-serif;
                         font-size:16px;line-height:1.7;color:#1B1A17;
                         white-space:pre-wrap;">{text}</td>
            </tr>"""

OTP_FOOTER = (
    "The code lasts ten minutes and can be used once. If this was not you, "
    "ignore this message — nobody can act on it without the code."
)


def _escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


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

    def _message(
        self, *, to: str, subject: str, body: str, html: str
    ) -> EmailMessage:
        message = EmailMessage()
        message["From"] = self._from
        message["To"] = to
        message["Subject"] = subject
        message.set_content(body)
        message.add_alternative(html, subtype="html")
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
        intro = INTROS.get(purpose, DEFAULT_INTRO)
        await self._deliver(
            self._message(
                to=email,
                subject=SUBJECTS.get(purpose, DEFAULT_SUBJECT),
                body=BODY.format(intro=intro, otp=otp),
                html=HTML_SHELL.format(
                    intro=_escape(intro),
                    body=OTP_BLOCK.format(otp=_escape(otp)),
                    footer=OTP_FOOTER,
                ),
            ),
            code=purpose,
        )

    async def send_security_alert(self, *, email: str, subject: str, body: str) -> None:
        await self._deliver(
            self._message(
                to=email,
                subject=subject,
                body=body,
                html=HTML_SHELL.format(
                    intro="Something happened on your Story account.",
                    body=TEXT_BLOCK.format(text=_escape(body)),
                    footer="If this was you, there is nothing to do.",
                ),
            ),
            code="security_alert",
        )
