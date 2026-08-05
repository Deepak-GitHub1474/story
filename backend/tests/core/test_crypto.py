import pytest

from app.core.crypto import (
    blind_index,
    decrypt_email,
    encrypt_email,
    mask_email,
    normalize_email,
)

KEY = "a" * 64
INDEX_KEY = "b" * 64


def test_normalize_lowercases_and_trims():
    assert normalize_email("  Deepak@Example.COM ") == "deepak@example.com"


def test_normalize_applies_nfkc():
    assert normalize_email("ﬁle@example.com") == "file@example.com"


def test_blind_index_is_deterministic():
    assert blind_index("a@b.com", key=INDEX_KEY) == blind_index("a@b.com", key=INDEX_KEY)


def test_blind_index_differs_per_address():
    assert blind_index("a@b.com", key=INDEX_KEY) != blind_index("c@d.com", key=INDEX_KEY)


def test_blind_index_differs_per_key():
    assert blind_index("a@b.com", key=INDEX_KEY) != blind_index("a@b.com", key=KEY)


def test_blind_index_does_not_contain_the_address():
    assert "a@b.com" not in blind_index("a@b.com", key=INDEX_KEY)


def test_blind_index_is_not_a_plain_sha256_of_the_address():
    import hashlib

    plain = hashlib.sha256(b"a@b.com").hexdigest()
    assert blind_index("a@b.com", key=INDEX_KEY) != plain


def test_email_round_trips_through_encryption():
    ciphertext = encrypt_email("deepak@example.com", key=KEY)
    assert decrypt_email(ciphertext, key=KEY) == "deepak@example.com"


def test_encryption_is_randomized():
    assert encrypt_email("a@b.com", key=KEY) != encrypt_email("a@b.com", key=KEY)


def test_ciphertext_does_not_contain_the_address():
    assert b"a@b.com" not in encrypt_email("a@b.com", key=KEY)


def test_decrypt_rejects_the_wrong_key():
    ciphertext = encrypt_email("a@b.com", key=KEY)
    with pytest.raises(ValueError, match="decrypt"):
        decrypt_email(ciphertext, key="c" * 64)


def test_decrypt_rejects_tampered_ciphertext():
    ciphertext = bytearray(encrypt_email("a@b.com", key=KEY))
    ciphertext[-1] ^= 0xFF
    with pytest.raises(ValueError, match="decrypt"):
        decrypt_email(bytes(ciphertext), key=KEY)


def test_mask_hides_most_of_the_local_part():
    masked = mask_email("deepak@gmail.com")
    assert masked.startswith("d")
    assert "eepa" not in masked
    assert masked.endswith(".com")


def test_mask_keeps_the_shape_recognisable():
    assert mask_email("deepak@gmail.com").count("@") == 1


def test_mask_handles_a_single_character_local_part():
    assert mask_email("a@b.com").startswith("a")


def test_mask_never_returns_the_full_address():
    assert mask_email("deepak@gmail.com") != "deepak@gmail.com"
