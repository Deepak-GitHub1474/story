import pytest

from app.core.ids import REFERRAL_ALPHABET, REFERRAL_CODE_LENGTH, new_id, new_referral_code


def test_new_id_carries_its_typed_prefix():
    assert new_id("usr").startswith("usr_")


def test_new_id_is_unique_across_calls():
    assert len({new_id("usr") for _ in range(1000)}) == 1000


def test_new_id_sorts_chronologically():
    ids = [new_id("sto") for _ in range(50)]
    assert ids == sorted(ids)


def test_new_id_rejects_an_unknown_prefix():
    with pytest.raises(ValueError, match="Unknown id prefix"):
        new_id("nope")


def test_referral_code_has_the_declared_length():
    assert len(new_referral_code()) == REFERRAL_CODE_LENGTH


def test_referral_code_uses_only_unambiguous_characters():
    for _ in range(200):
        assert set(new_referral_code()) <= set(REFERRAL_ALPHABET)


def test_referral_alphabet_excludes_visually_ambiguous_glyphs():
    assert not set("O0I1L") & set(REFERRAL_ALPHABET)


def test_referral_codes_are_not_sequential():
    codes = [new_referral_code() for _ in range(500)]
    assert len(set(codes)) == len(codes)
