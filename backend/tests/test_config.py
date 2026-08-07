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
    "MAIL_PROVIDER": "smtp",
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


def test_s3_storage_without_credentials_is_refused():
    from app.ports.factory import build_storage

    settings = production(STORAGE_PROVIDER="s3")
    with pytest.raises(ValueError) as caught:
        build_storage(settings)

    assert "STORAGE_S3_ENDPOINT" in str(caught.value)
    assert "STORAGE_S3_BUCKET_VAULT" in str(caught.value)


def test_s3_storage_with_credentials_builds():
    from app.ports.factory import build_storage

    settings = production(
        STORAGE_PROVIDER="s3",
        STORAGE_S3_ENDPOINT="https://acc.r2.cloudflarestorage.com",
        STORAGE_S3_ACCESS_KEY="a" * 20,
        STORAGE_S3_SECRET_KEY="b" * 40,
        STORAGE_S3_BUCKET_VAULT="story-vault",
    )
    storage = build_storage(settings)

    assert storage.key_for(owner_id="usr_1", item_id="vit_2") == "vault/usr_1/vit_2"


def test_r2_is_an_accepted_provider_name():
    from app.ports.factory import build_storage

    settings = production(
        STORAGE_PROVIDER="r2",
        STORAGE_S3_ENDPOINT="https://acc.r2.cloudflarestorage.com",
        STORAGE_S3_ACCESS_KEY="a" * 20,
        STORAGE_S3_SECRET_KEY="b" * 40,
        STORAGE_S3_BUCKET_VAULT="story-vault",
    )

    assert build_storage(settings).key_for(owner_id="u", item_id="i") == "vault/u/i"


def test_r2_and_s3_build_the_same_adapter():
    from app.ports.factory import build_storage

    common = {
        "STORAGE_S3_ENDPOINT": "https://acc.r2.cloudflarestorage.com",
        "STORAGE_S3_ACCESS_KEY": "a" * 20,
        "STORAGE_S3_SECRET_KEY": "b" * 40,
        "STORAGE_S3_BUCKET_VAULT": "story-vault",
    }

    as_r2 = build_storage(production(STORAGE_PROVIDER="r2", **common))
    as_s3 = build_storage(production(STORAGE_PROVIDER="s3", **common))

    assert type(as_r2) is type(as_s3)


def test_r2_without_credentials_is_refused_too():
    from app.ports.factory import build_storage

    with pytest.raises(ValueError) as caught:
        build_storage(production(STORAGE_PROVIDER="r2"))

    assert "STORAGE_S3_ENDPOINT" in str(caught.value)


def test_smtp_mail_without_credentials_is_refused():
    from app.ports.factory import build_mail

    with pytest.raises(ValueError) as caught:
        build_mail(production(MAIL_PROVIDER="smtp"))

    assert "SMTP_HOST" in str(caught.value)


def test_smtp_mail_with_credentials_builds():
    from app.ports.factory import build_mail

    mail = build_mail(
        production(
            MAIL_PROVIDER="smtp",
            SMTP_HOST="smtp.example.com",
            SMTP_USERNAME="postmaster@story.test",
            SMTP_PASSWORD="a-secret",
            MAIL_FROM="Story <hello@story.test>",
        )
    )

    assert hasattr(mail, "send_otp")


def test_a_placeholder_key_is_refused_rather_than_failing_at_publish_time():
    from app.config import Settings
    from app.ports.factory import build_ai

    settings = Settings(AI_PROVIDER="gemini", AI_API_KEY="replace-with-your-google-ai-studio-key")

    with pytest.raises(ValueError, match="AI_API_KEY"):
        build_ai(settings)


def test_a_dummy_key_is_refused_too():
    from app.config import Settings
    from app.ports.factory import build_ai

    with pytest.raises(ValueError, match="AI_API_KEY"):
        build_ai(Settings(AI_PROVIDER="gemini", AI_API_KEY="dummy-google-ai-studio-key"))


def test_a_real_looking_key_is_accepted():
    from app.config import Settings
    from app.ports.factory import build_ai

    adapter = build_ai(
        Settings(AI_PROVIDER="gemini", AI_API_KEY="AIzaSyD-a-real-looking-key-000000000000")
    )

    assert adapter.is_available


def test_r2_storage_needs_no_code_change_only_credentials():
    from app.config import Settings
    from app.ports.factory import build_storage

    adapter = build_storage(
        Settings(
            STORAGE_PROVIDER="r2",
            STORAGE_S3_ENDPOINT="https://acct.r2.cloudflarestorage.com",
            STORAGE_S3_ACCESS_KEY="an-access-key",
            STORAGE_S3_SECRET_KEY="a-secret-key",
            STORAGE_S3_BUCKET_VAULT="story-vault",
            STORAGE_S3_BUCKET_MEDIA="story-media",
        )
    )

    assert adapter.key_for(owner_id="usr_1", item_id="vit_1")


def test_the_suite_never_calls_a_real_provider():
    from app.config import Settings

    settings = Settings()

    assert settings.AI_PROVIDER == "none"
    assert settings.MAIL_PROVIDER == "console"
