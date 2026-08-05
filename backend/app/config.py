from functools import lru_cache
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    APP_NAME: str = "Story API"
    APP_VERSION: str = "0.1.0"
    API_ENV: Literal["local", "staging", "production"] = "local"
    API_PREFIX: str = "/v1"
    HOST: str = "127.0.0.1"
    PORT: int = 9000
    LOG_LEVEL: str = "INFO"
    CORS_ORIGINS: str = "http://localhost:3000"
    PUBLIC_WEB_URL: str = "https://story.app"

    MAIL_PROVIDER: Literal["console", "resend", "smtp"] = "console"
    EMAIL_INDEX_KEY: str = "local-dev-email-index-key-change-me-000000000000"
    EMAIL_ENCRYPTION_KEY: str = "local-dev-email-encryption-key-change-me-0000"
    OTP_HMAC_SECRET: str = "local-dev-otp-secret-change-me-00000000000000"
    OTP_TTL_SECONDS: int = 600
    OTP_FAIL_THRESHOLD: int = 5
    OTP_LOCKOUT_SECONDS: int = 900
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

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def is_local(self) -> bool:
        return self.API_ENV == "local"

    @model_validator(mode="after")
    def enforce_production_invariants(self) -> "Settings":
        if self.API_ENV == "production":
            if not self.COOKIE_SECURE:
                raise ValueError("COOKIE_SECURE must be true in production.")
            if "*" in self.CORS_ORIGINS:
                raise ValueError("CORS_ORIGINS cannot contain a wildcard in production.")
            if len(self.JWT_SECRET) < 32 or "change-me" in self.JWT_SECRET:
                raise ValueError("JWT_SECRET must be a real secret of 32+ characters.")
            for name in ("EMAIL_INDEX_KEY", "EMAIL_ENCRYPTION_KEY", "OTP_HMAC_SECRET"):
                if "change-me" in getattr(self, name):
                    raise ValueError(f"{name} must be a real secret in production.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
