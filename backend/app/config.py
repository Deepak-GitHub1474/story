from functools import lru_cache
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

SECRET_SETTINGS = (
    "JWT_SECRET",
    "EMAIL_INDEX_KEY",
    "EMAIL_ENCRYPTION_KEY",
    "OTP_HMAC_SECRET",
)

PLACEHOLDER_MARKERS = ("change-me", "changeme", "local-dev", "example", "placeholder")
LOCAL_HOSTS = ("localhost", "127.0.0.1", "0.0.0.0")
MIN_SECRET_LENGTH = 32
MIN_SECRET_ALPHABET = 8


def _secret_problems(name: str, value: str) -> list[str]:
    problems = []
    lowered = value.lower()

    if any(marker in lowered for marker in PLACEHOLDER_MARKERS):
        problems.append(f"{name} still holds a placeholder value.")
    if len(value) < MIN_SECRET_LENGTH:
        problems.append(f"{name} must be at least {MIN_SECRET_LENGTH} characters.")
    if len(set(value)) < MIN_SECRET_ALPHABET:
        problems.append(f"{name} is not random enough.")

    return problems


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    APP_NAME: str = "Story API"
    TOTP_ISSUER: str = "Story"
    APP_VERSION: str = "0.1.0"
    API_ENV: Literal["local", "staging", "production"] = "local"
    API_PREFIX: str = "/v1"
    HOST: str = "127.0.0.1"
    PORT: int = 9000
    LOG_LEVEL: str = "INFO"
    CORS_ORIGINS: str = "http://localhost:3000"
    PUBLIC_WEB_URL: str = "https://story.app"

    MAIL_PROVIDER: Literal["console", "smtp"] = "console"
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = True
    MAIL_FROM: str = "Story <no-reply@story.local>"
    EMAIL_INDEX_KEY: str = "local-dev-email-index-key-change-me-000000000000"
    EMAIL_ENCRYPTION_KEY: str = "local-dev-email-encryption-key-change-me-0000"
    OTP_HMAC_SECRET: str = "local-dev-otp-secret-change-me-00000000000000"
    OTP_TTL_SECONDS: int = 600
    OTP_FAIL_THRESHOLD: int = 5
    OTP_LOCKOUT_SECONDS: int = 30
    OTP_RESEND_COOLDOWN_SECONDS: int = 30
    RESET_TOKEN_TTL_SECONDS: int = 900

    MONGODB_URI: str = "mongodb://127.0.0.1:27017"
    MONGODB_DB_NAME: str = "story_local"
    REDIS_URL: str = "redis://127.0.0.1:6379/0"
    ENSURE_INDEXES_ON_BOOT: bool = True
    RUN_BACKGROUND_JOBS: bool = True

    JWT_SECRET: str = Field(default="local-dev-secret-change-me-0123456789abcdef")
    ACCESS_TOKEN_TTL_MINUTES: int = 30
    REFRESH_TOKEN_TTL_DAYS: int = 30

    COOKIE_SECURE: bool = False
    COOKIE_SAMESITE: Literal["lax", "strict", "none"] = "lax"
    ACCESS_COOKIE_NAME: str = "story_access"
    REFRESH_COOKIE_NAME: str = "story_refresh"
    CSRF_COOKIE_NAME: str = "story_csrf"
    CSRF_HEADER_NAME: str = "x-csrf-token"

    RATE_LIMIT_ENABLED: bool = True

    STORAGE_PROVIDER: Literal["local", "s3", "r2"] = "local"
    STORAGE_LOCAL_ROOT: str = ".storage"
    STORAGE_LOCAL_BASE_URL: str = "http://127.0.0.1:9000/v1/storage"
    STORAGE_S3_ENDPOINT: str = ""
    STORAGE_S3_REGION: str = "auto"
    STORAGE_S3_ACCESS_KEY: str = ""
    STORAGE_S3_SECRET_KEY: str = ""
    STORAGE_S3_BUCKET_VAULT: str = ""
    STORAGE_S3_BUCKET_MEDIA: str = ""
    AI_PROVIDER: Literal["none", "gemini"] = "none"
    AI_API_KEY: str = ""
    AI_MODEL: str = "gemini-3.5-flash-lite"
    AI_TIMEOUT_SECONDS: float = 20.0
    PRESIGN_UPLOAD_TTL_SECONDS: int = 900
    PRESIGN_DOWNLOAD_TTL_SECONDS: int = 300
    VAULT_QUOTA_BYTES: int = 2 * 1024**3
    VAULT_MAX_ITEM_BYTES: int = 10 * 1024**2
    VAULT_MAX_IMAGE_BYTES: int = 10 * 1024**2
    VAULT_MAX_VIDEO_BYTES: int = 10 * 1024**2
    VAULT_MAX_PDF_BYTES: int = 10 * 1024**2
    VAULT_MAX_ITEMS: int = 2000
    COMPRESS_ABOVE_BYTES: int = 1024**2

    def limit_for(self, kind: str) -> int:
        return {
            "image": self.VAULT_MAX_IMAGE_BYTES,
            "video": self.VAULT_MAX_VIDEO_BYTES,
            "pdf": self.VAULT_MAX_PDF_BYTES,
        }.get(
            kind,
            min(
                self.VAULT_MAX_IMAGE_BYTES,
                self.VAULT_MAX_VIDEO_BYTES,
                self.VAULT_MAX_PDF_BYTES,
            ),
        )

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def is_local(self) -> bool:
        return self.API_ENV == "local"

    @model_validator(mode="after")
    def enforce_production_invariants(self) -> "Settings":
        if self.API_ENV != "production":
            return self

        problems: list[str] = []

        for name in SECRET_SETTINGS:
            problems.extend(_secret_problems(name, getattr(self, name)))

        values = [getattr(self, name) for name in SECRET_SETTINGS]
        if len(set(values)) != len(values):
            problems.append("Every secret must be distinct from the others.")

        if not self.COOKIE_SECURE:
            problems.append("COOKIE_SECURE must be true in production.")
        if "*" in self.CORS_ORIGINS:
            problems.append("CORS_ORIGINS cannot contain a wildcard in production.")
        if not self.RATE_LIMIT_ENABLED:
            problems.append("RATE_LIMIT_ENABLED must be true in production.")
        if self.MAIL_PROVIDER == "console":
            problems.append("MAIL_PROVIDER cannot be console in production.")
        for name in ("MONGODB_URI", "REDIS_URL"):
            if any(host in getattr(self, name) for host in LOCAL_HOSTS):
                problems.append(f"{name} must not point at localhost in production.")

        if problems:
            raise ValueError(" ".join(problems))
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
