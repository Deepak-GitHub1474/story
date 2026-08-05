from typing import Protocol


class MailPort(Protocol):
    async def send_otp(self, *, email: str, otp: str, purpose: str) -> None: ...

    async def send_security_alert(self, *, email: str, subject: str, body: str) -> None: ...
