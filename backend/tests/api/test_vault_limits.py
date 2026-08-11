import pytest

from app.config import Settings


@pytest.mark.parametrize(
    ("kind", "setting"),
    [
        ("image", "VAULT_MAX_IMAGE_BYTES"),
        ("video", "VAULT_MAX_VIDEO_BYTES"),
        ("pdf", "VAULT_MAX_PDF_BYTES"),
    ],
)
def test_every_kind_has_its_own_limit(kind, setting):
    settings = Settings()
    assert getattr(settings, setting) > 0
    assert settings.limit_for(kind) == getattr(settings, setting)


def test_the_limits_all_start_at_ten_megabytes():
    settings = Settings()
    ten = 10 * 1024**2

    assert settings.limit_for("image") == ten
    assert settings.limit_for("video") == ten
    assert settings.limit_for("pdf") == ten


def test_a_limit_can_be_raised_for_one_kind_alone():
    settings = Settings(VAULT_MAX_VIDEO_BYTES=50 * 1024**2)

    assert settings.limit_for("video") == 50 * 1024**2
    assert settings.limit_for("image") == 10 * 1024**2


def test_an_unknown_kind_falls_back_to_the_smallest_limit():
    settings = Settings(VAULT_MAX_VIDEO_BYTES=50 * 1024**2)

    assert settings.limit_for("something-else") == 10 * 1024**2


def test_compression_starts_only_above_a_threshold():
    settings = Settings()

    assert settings.COMPRESS_ABOVE_BYTES > 0
    assert settings.COMPRESS_ABOVE_BYTES < settings.VAULT_MAX_IMAGE_BYTES
