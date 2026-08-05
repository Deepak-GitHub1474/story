import pytest
from pydantic import ValidationError

from app.config import Settings

REAL = {
    "JWT_SECRET": "qtZ8vN3xLp7Rw2KdF9hJc4MbY6sA1eUg",
    "EMAIL_INDEX_KEY": "Hn5PjW8kQz2XcV7bR4mL9tYd3sGf6aEu",
    "EMAIL_ENCRYPTION_KEY": "Zx4Kq9Vn2Mw7Jb5Rt8Lp3Yc6Hd1Gs0Fa",
    "OTP_HMAC_SECRET": "Ld7Bq2Nx9Kv4Tm6Rc8Jp1Wy5Hf3Za0Sg",
}


BASE = {
    "API_ENV": "production",
    "CORS_ORIGINS": "https://story.app",
    "COOKIE_SECURE": True,
    "MAIL_PROVIDER": "resend",
    "MONGODB_URI": "mongodb://prod-cluster:27017",
    "MONGODB_DB_NAME": "story",
    "REDIS_URL": "redis://prod-cache:6379/0",
    "RATE_LIMIT_ENABLED": True,
    "RUN_BACKGROUND_JOBS": True,
}


def production(**overrides):
    return Settings(_env_file=None, **{**BASE, **REAL, **overrides})


def test_a_correct_production_config_is_accepted():
    assert production().API_ENV == "production"


def test_local_defaults_are_usable_without_any_env_file():
    settings = Settings(_env_file=None)
    assert settings.API_ENV == "local"


@pytest.mark.parametrize("name", sorted(REAL))
def test_a_placeholder_secret_is_refused_in_production(name):
    with pytest.raises(ValidationError, match=name):
        production(**{name: "local-dev-change-me-0000000000000000000000000000"})


@pytest.mark.parametrize("name", sorted(REAL))
def test_a_short_secret_is_refused_in_production(name):
    with pytest.raises(ValidationError, match=name):
        production(**{name: "tooshort"})


@pytest.mark.parametrize("name", sorted(REAL))
def test_a_repeated_character_secret_is_refused_in_production(name):
    with pytest.raises(ValidationError, match=name):
        production(**{name: "a" * 48})


def test_insecure_cookies_are_refused_in_production():
    with pytest.raises(ValidationError, match="COOKIE_SECURE"):
        production(COOKIE_SECURE=False)


def test_a_wildcard_origin_is_refused_in_production():
    with pytest.raises(ValidationError, match="CORS_ORIGINS"):
        production(CORS_ORIGINS="*")


def test_disabled_rate_limiting_is_refused_in_production():
    with pytest.raises(ValidationError, match="RATE_LIMIT_ENABLED"):
        production(RATE_LIMIT_ENABLED=False)


def test_the_console_mailer_is_refused_in_production():
    with pytest.raises(ValidationError, match="MAIL_PROVIDER"):
        production(MAIL_PROVIDER="console")


def test_a_local_mongo_uri_is_refused_in_production():
    with pytest.raises(ValidationError, match="MONGODB_URI"):
        production(MONGODB_URI="mongodb://127.0.0.1:27017")


def test_two_secrets_may_not_be_the_same():
    with pytest.raises(ValidationError, match="distinct"):
        production(EMAIL_INDEX_KEY=REAL["JWT_SECRET"])


def test_local_tolerates_everything_production_refuses():
    settings = Settings(
        _env_file=None,
        API_ENV="local",
        RATE_LIMIT_ENABLED=False,
        MAIL_PROVIDER="console",
        COOKIE_SECURE=False,
    )
    assert settings.MAIL_PROVIDER == "console"
