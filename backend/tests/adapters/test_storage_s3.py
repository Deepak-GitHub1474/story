from urllib.parse import parse_qs, urlparse

import pytest

from app.adapters.storage_s3 import S3Adapter


@pytest.fixture
def adapter():
    return S3Adapter(
        access_key="AKIAIOSFODNN7EXAMPLE",
        secret_key="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region="auto",
        endpoint="https://acc.r2.cloudflarestorage.com",
        buckets={"vault": "story-vault", "media": "story-media"},
    )


def test_the_object_key_is_scoped_to_the_owner(adapter):
    assert adapter.key_for(owner_id="usr_1", item_id="vit_2") == "vault/usr_1/vit_2"


async def test_an_upload_url_is_a_put_against_the_right_bucket(adapter):
    url = await adapter.presign_put(profile="vault", key="vault/usr_1/vit_2", expires_in=900)
    parsed = urlparse(url)

    assert parsed.netloc == "acc.r2.cloudflarestorage.com"
    assert parsed.path == "/story-vault/vault/usr_1/vit_2"
    assert parse_qs(parsed.query)["X-Amz-Expires"] == ["900"]


async def test_a_download_url_differs_from_an_upload_url(adapter):
    put = await adapter.presign_put(profile="vault", key="k", expires_in=300)
    get = await adapter.presign_get(profile="vault", key="k", expires_in=300)

    assert parse_qs(urlparse(put).query)["X-Amz-Signature"] != (
        parse_qs(urlparse(get).query)["X-Amz-Signature"]
    )


async def test_each_profile_uses_its_own_bucket(adapter):
    vault = await adapter.presign_get(profile="vault", key="k", expires_in=60)
    media = await adapter.presign_get(profile="media", key="k", expires_in=60)

    assert "/story-vault/" in vault
    assert "/story-media/" in media


async def test_an_unknown_profile_is_refused(adapter):
    with pytest.raises(ValueError):
        await adapter.presign_get(profile="nope", key="k", expires_in=60)


async def test_the_secret_never_reaches_the_url(adapter):
    url = await adapter.presign_get(profile="vault", key="k", expires_in=60)
    assert "wJalrXUtnFEMI" not in url


async def test_download_urls_forbid_caching_and_declare_a_blob(adapter):
    url = await adapter.presign_get(profile="vault", key="k", expires_in=60)
    query = parse_qs(urlparse(url).query)

    assert query["response-cache-control"] == ["private, no-store"]
    assert query["response-content-type"] == ["application/octet-stream"]


async def test_upload_urls_do_not_carry_response_overrides(adapter):
    url = await adapter.presign_put(profile="vault", key="k", expires_in=60)
    assert "response-cache-control" not in url


def test_a_missing_bucket_map_is_a_startup_error():
    with pytest.raises(ValueError):
        S3Adapter(
            access_key="a",
            secret_key="b",
            region="auto",
            endpoint="https://x.example.com",
            buckets={},
        )
