import secrets

from ulid import ULID

ID_PREFIXES: frozenset[str] = frozenset(
    {
        "usr",
        "sto",
        "cmt",
        "com",
        "vit",
        "tkt",
        "aud",
        "not",
        "dev",
        "rep",
        "pcd",
        "rev",
        "cnv",
        "msg",
        "med",
        "psh",
    }
)

REFERRAL_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
REFERRAL_CODE_LENGTH = 6


def new_id(prefix: str) -> str:
    if prefix not in ID_PREFIXES:
        raise ValueError(f"Unknown id prefix: {prefix!r}")
    return f"{prefix}_{ULID()}"


def new_referral_code() -> str:
    return "".join(secrets.choice(REFERRAL_ALPHABET) for _ in range(REFERRAL_CODE_LENGTH))
