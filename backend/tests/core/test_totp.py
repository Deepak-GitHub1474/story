import base64
import time

import pytest

from app.core.totp import (
    STEP_SECONDS,
    code_at,
    hash_backup_code,
    new_backup_codes,
    new_secret,
    provisioning_uri,
    verify,
)

RFC_SECRET = base64.b32encode(b"12345678901234567890").decode()


def test_a_new_secret_is_base32_and_long_enough():
    secret = new_secret()
    assert len(base64.b32decode(secret)) == 20


def test_two_secrets_are_never_the_same():
    assert new_secret() != new_secret()


@pytest.mark.parametrize(
    ("moment", "expected"),
    [(59, "287082"), (1111111109, "081804"), (1234567890, "005924")],
)
def test_it_matches_the_rfc_6238_vectors(moment, expected):
    assert code_at(RFC_SECRET, moment) == expected


def test_the_current_code_verifies():
    secret = new_secret()
    assert verify(secret, code_at(secret, int(time.time()))) is True


def test_a_wrong_code_is_refused():
    secret = new_secret()
    assert verify(secret, "000000") is False


def test_the_previous_step_still_verifies_for_clock_drift():
    secret = new_secret()
    now = int(time.time())
    assert verify(secret, code_at(secret, now - STEP_SECONDS), at=now) is True


def test_the_next_step_verifies_for_clock_drift():
    secret = new_secret()
    now = int(time.time())
    assert verify(secret, code_at(secret, now + STEP_SECONDS), at=now) is True


def test_a_code_two_steps_old_is_refused():
    secret = new_secret()
    now = int(time.time())
    assert verify(secret, code_at(secret, now - STEP_SECONDS * 2), at=now) is False


def test_a_code_from_another_secret_is_refused():
    mine, theirs = new_secret(), new_secret()
    now = int(time.time())
    assert verify(mine, code_at(theirs, now), at=now) is False


def test_a_malformed_code_is_refused_without_raising():
    secret = new_secret()
    for bad in ("", "abc", "12345", "1234567", "12 34 56", None):
        assert verify(secret, bad) is False


def test_the_provisioning_uri_carries_the_secret_and_issuer():
    secret = new_secret()
    uri = provisioning_uri(secret, username="deepak", issuer="Story")

    assert uri.startswith("otpauth://totp/Story:deepak?")
    assert f"secret={secret}" in uri
    assert "issuer=Story" in uri
    assert "digits=6" in uri
    assert "period=30" in uri


def test_backup_codes_are_distinct_and_hashed_one_way():
    codes = new_backup_codes()

    assert len(codes) == 8
    assert len(set(codes)) == 8
    for code in codes:
        assert len(code) == 10
        assert hash_backup_code(code, secret="k") != code


def test_the_same_backup_code_hashes_the_same_way():
    code = new_backup_codes()[0]
    assert hash_backup_code(code, secret="k") == hash_backup_code(code, secret="k")


def test_a_backup_code_hash_depends_on_the_server_secret():
    code = new_backup_codes()[0]
    assert hash_backup_code(code, secret="one") != hash_backup_code(code, secret="two")
