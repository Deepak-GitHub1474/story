from functools import lru_cache

from app.adapters.mail_console import ConsoleMailAdapter
from app.adapters.storage_local import LocalDiskAdapter
from app.config import Settings
from app.ports.mail import MailPort
from app.ports.storage import StoragePort


@lru_cache
def _console() -> ConsoleMailAdapter:
    return ConsoleMailAdapter()


def build_mail(settings: Settings) -> MailPort:
    if settings.MAIL_PROVIDER == "console":
        return _console()
    raise ValueError(f"Unknown mail provider: {settings.MAIL_PROVIDER}")


@lru_cache
def _local_disk(root: str, base_url: str, secret: str) -> LocalDiskAdapter:
    return LocalDiskAdapter(root=root, base_url=base_url, secret=secret)


def build_storage(settings: Settings) -> StoragePort:
    if settings.STORAGE_PROVIDER == "local":
        return _local_disk(
            settings.STORAGE_LOCAL_ROOT,
            settings.STORAGE_LOCAL_BASE_URL,
            settings.JWT_SECRET,
        )
    raise ValueError(f"Unknown storage provider: {settings.STORAGE_PROVIDER}")
