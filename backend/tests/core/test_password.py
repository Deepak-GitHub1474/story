import pytest

from app.core.password import (
    PASSWORD_MIN_LENGTH,
    hash_password,
    needs_rehash,
    validate_password_strength,
    verify_password,
)

VALID = "correct horse battery"


def test_hash_is_an_argon2id_phc_string():
    assert hash_password(VALID).startswith("$argon2id$")


def test_hash_is_salted_so_two_identical_passwords_differ():
    assert hash_password(VALID) != hash_password(VALID)


def test_verify_accepts_the_correct_password():
    assert verify_password(VALID, hash_password(VALID)) is True


def test_verify_rejects_a_wrong_password():
    assert verify_password("something else entirely", hash_password(VALID)) is False


def test_verify_returns_false_on_a_malformed_hash_instead_of_raising():
    assert verify_password(VALID, "not-a-hash") is False


def test_needs_rehash_is_false_for_a_hash_made_with_current_parameters():
    assert needs_rehash(hash_password(VALID)) is False


def test_needs_rehash_is_true_for_a_weaker_legacy_hash():
    weak = "$argon2id$v=19$m=8,t=1,p=1$c29tZXNhbHRzYWx0$" + "A" * 43
    assert needs_rehash(weak) is True


def test_strength_rejects_a_password_under_the_minimum_length():
    with pytest.raises(ValueError, match=str(PASSWORD_MIN_LENGTH)):
        validate_password_strength("short", username="deepak")


def test_strength_rejects_a_password_containing_the_username():
    with pytest.raises(ValueError, match="username"):
        validate_password_strength("deepak-is-here", username="deepak")


def test_strength_rejects_the_username_case_insensitively():
    with pytest.raises(ValueError, match="username"):
        validate_password_strength("DEEPAK-is-here", username="deepak")


def test_strength_rejects_a_commonly_breached_password():
    with pytest.raises(ValueError, match="common"):
        validate_password_strength("password123", username="deepak")


def test_strength_accepts_a_long_unrelated_password():
    validate_password_strength(VALID, username="deepak")


def test_strength_has_no_composition_rules():
    validate_password_strength("aaaaaaaaaaaaaaaaaaaa", username="deepak")
