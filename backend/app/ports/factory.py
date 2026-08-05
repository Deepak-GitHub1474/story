from functools import lru_cache

from app.adapters.mail_console import ConsoleMailAdapter
from app.config import Settings
from app.ports.mail import MailPort


@lru_cache
def _console() -> ConsoleMailAdapter:
    return ConsoleMailAdapter()


def build_mail(settings: Settings) -> MailPort:
    if settings.MAIL_PROVIDER == "console":
        return _console()
    raise ValueError(f"Unknown mail provider: {settings.MAIL_PROVIDER}")
