from functools import lru_cache

from app.adapters.ai_gemini import GeminiAdapter
from app.adapters.ai_none import NoAIAdapter
from app.adapters.mail_console import ConsoleMailAdapter
from app.adapters.mail_smtp import SmtpMailAdapter
from app.adapters.storage_local import LocalDiskAdapter
from app.adapters.storage_s3 import S3Adapter
from app.config import Settings
from app.ports.ai import AIPort
from app.ports.mail import MailPort
from app.ports.storage import StoragePort


@lru_cache
def _console() -> ConsoleMailAdapter:
    return ConsoleMailAdapter()


@lru_cache
def _smtp(
    host: str, port: int, username: str, password: str, from_address: str, use_tls: bool
) -> SmtpMailAdapter:
    return SmtpMailAdapter(
        host=host,
        port=port,
        username=username,
        password=password,
        from_address=from_address,
        use_tls=use_tls,
    )


def build_mail(settings: Settings) -> MailPort:
    if settings.MAIL_PROVIDER == "console":
        return _console()
    if settings.MAIL_PROVIDER == "smtp":
        missing = [
            name
            for name in ("SMTP_HOST", "SMTP_USERNAME", "SMTP_PASSWORD", "MAIL_FROM")
            if not getattr(settings, name)
        ]
        if missing:
            raise ValueError(f"MAIL_PROVIDER=smtp needs: {', '.join(missing)}")
        return _smtp(
            settings.SMTP_HOST,
            settings.SMTP_PORT,
            settings.SMTP_USERNAME,
            settings.SMTP_PASSWORD,
            settings.MAIL_FROM,
            settings.SMTP_USE_TLS,
        )
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


@lru_cache
def _no_ai() -> NoAIAdapter:
    return NoAIAdapter()


@lru_cache
def _gemini(api_key: str, model: str, timeout: float) -> GeminiAdapter:
    return GeminiAdapter(api_key=api_key, model=model, timeout=timeout)


PLACEHOLDER_MARKERS = ("replace-with", "dummy", "changeme", "your-key")


def _is_placeholder(value: str) -> bool:
    lowered = value.lower()
    return any(marker in lowered for marker in PLACEHOLDER_MARKERS)


def build_ai(settings: Settings) -> AIPort:
    if settings.AI_PROVIDER == "none":
        return _no_ai()
    if settings.AI_PROVIDER == "gemini":
        if not settings.AI_API_KEY or _is_placeholder(settings.AI_API_KEY):
            raise ValueError(
                "AI_PROVIDER=gemini needs a real AI_API_KEY from aistudio.google.com/apikey"
            )
        return _gemini(settings.AI_API_KEY, settings.AI_MODEL, settings.AI_TIMEOUT_SECONDS)
    raise ValueError(f"Unknown AI provider: {settings.AI_PROVIDER}")
