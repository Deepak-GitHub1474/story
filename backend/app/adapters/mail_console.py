from typing import Any

from app.logging import get_logger

logger = get_logger("story.mail")

outbox: list[dict[str, Any]] = []


class ConsoleMailAdapter:
    async def send_otp(self, *, email: str, otp: str, purpose: str) -> None:
        outbox.append({"email": email, "otp": otp, "purpose": purpose})
        logger.info("mail_otp_sent", service="console", code=purpose)

    async def send_security_alert(self, *, email: str, subject: str, body: str) -> None:
        outbox.append({"email": email, "subject": subject, "body": body})
        logger.info("mail_alert_sent", service="console")
