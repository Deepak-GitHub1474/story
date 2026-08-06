from functools import lru_cache

from app.adapters.mail_console import ConsoleMailAdapter
from app.adapters.storage_local import LocalDiskAdapter
from app.adapters.storage_s3 import S3Adapter
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


@lru_cache
def _s3(
    access_key: str,
    secret_key: str,
    region: str,
    endpoint: str,
    vault_bucket: str,
    media_bucket: str,
) -> S3Adapter:
    buckets = {"vault": vault_bucket}
    if media_bucket:
        buckets["media"] = media_bucket
    return S3Adapter(
        access_key=access_key,
        secret_key=secret_key,
        region=region,
        endpoint=endpoint,
        buckets=buckets,
    )


def build_storage(settings: Settings) -> StoragePort:
    if settings.STORAGE_PROVIDER == "local":
        return _local_disk(
            settings.STORAGE_LOCAL_ROOT,
            settings.STORAGE_LOCAL_BASE_URL,
            settings.JWT_SECRET,
        )
    if settings.STORAGE_PROVIDER in ("s3", "r2"):
        missing = [
            name
            for name in (
                "STORAGE_S3_ENDPOINT",
                "STORAGE_S3_ACCESS_KEY",
                "STORAGE_S3_SECRET_KEY",
                "STORAGE_S3_BUCKET_VAULT",
            )
            if not getattr(settings, name)
        ]
        if missing:
            raise ValueError(f"STORAGE_PROVIDER=s3 needs: {', '.join(missing)}")
        return _s3(
            settings.STORAGE_S3_ACCESS_KEY,
            settings.STORAGE_S3_SECRET_KEY,
            settings.STORAGE_S3_REGION,
            settings.STORAGE_S3_ENDPOINT,
            settings.STORAGE_S3_BUCKET_VAULT,
            settings.STORAGE_S3_BUCKET_MEDIA,
        )
    raise ValueError(f"Unknown storage provider: {settings.STORAGE_PROVIDER}")
