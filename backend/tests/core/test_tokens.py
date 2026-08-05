from datetime import timedelta

import pytest

from app.core.time import utc_now
from app.core.tokens import (
    REFRESH_TOKEN_BYTES,
    AccessClaims,
    TokenError,
    create_access_token,
    decode_access_token,
    hash_refresh_token,
    new_family_id,
    new_refresh_token,
)

SECRET = "a-test-secret-that-is-at-least-32-characters-long"


def claims(**overrides) -> dict:
    return {"user_id": "usr_01J9X", "role": "user", "family_id": "fam_1", **overrides}


def test_access_token_round_trips_its_claims():
    token = create_access_token(**claims(), secret=SECRET)
    decoded = decode_access_token(token, secret=SECRET)
    assert decoded.user_id == "usr_01J9X"
    assert decoded.role == "user"
    assert decoded.family_id == "fam_1"


def test_access_token_carries_a_unique_jti_for_revocation():
    a = decode_access_token(create_access_token(**claims(), secret=SECRET), secret=SECRET)
    b = decode_access_token(create_access_token(**claims(), secret=SECRET), secret=SECRET)
    assert a.jti != b.jti


def test_access_token_is_rejected_when_signed_with_another_secret():
    token = create_access_token(**claims(), secret=SECRET)
    with pytest.raises(TokenError, match="invalid"):
        decode_access_token(token, secret="a-different-secret-of-sufficient-length!!")


def test_access_token_is_rejected_once_expired():
    token = create_access_token(**claims(), secret=SECRET, ttl=timedelta(seconds=-1))
    with pytest.raises(TokenError, match="expired"):
        decode_access_token(token, secret=SECRET)


def test_access_token_is_rejected_when_malformed():
    with pytest.raises(TokenError, match="invalid"):
        decode_access_token("not.a.token", secret=SECRET)


def test_access_token_expiry_reflects_the_requested_ttl():
    token = create_access_token(**claims(), secret=SECRET, ttl=timedelta(minutes=30))
    decoded = decode_access_token(token, secret=SECRET)
    assert timedelta(minutes=29) < decoded.expires_at - utc_now() <= timedelta(minutes=30)


def test_access_token_omits_mutable_profile_data():
    assert "display_name" not in AccessClaims.model_fields


def test_refresh_token_is_high_entropy():
    assert len({new_refresh_token() for _ in range(500)}) == 500


def test_refresh_token_is_url_safe():
    token = new_refresh_token()
    assert token.isascii() and "/" not in token and "+" not in token


def test_refresh_token_hash_is_deterministic():
    token = new_refresh_token()
    assert hash_refresh_token(token) == hash_refresh_token(token)


def test_refresh_token_hash_does_not_reveal_the_token():
    token = new_refresh_token()
    assert token not in hash_refresh_token(token)


def test_refresh_tokens_of_different_values_hash_differently():
    assert hash_refresh_token(new_refresh_token()) != hash_refresh_token(new_refresh_token())


def test_family_ids_are_unique():
    assert len({new_family_id() for _ in range(200)}) == 200


def test_refresh_token_uses_the_declared_entropy():
    assert REFRESH_TOKEN_BYTES >= 32
