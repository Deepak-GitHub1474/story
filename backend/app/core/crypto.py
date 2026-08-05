import hashlib
import hmac
import secrets
import unicodedata

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

NONCE_BYTES = 12
EMAIL_AAD = b"story.email.v1"
MASK_CHARACTER = "•"
MASK_WIDTH = 4


def normalize_email(value: str) -> str:
    return unicodedata.normalize("NFKC", value).strip().lower()


def _derive(key: str) -> bytes:
    return hashlib.sha256(key.encode()).digest()


def blind_index(email: str, *, key: str) -> str:
    return hmac.new(_derive(key), normalize_email(email).encode(), hashlib.sha256).hexdigest()


def encrypt_email(email: str, *, key: str) -> bytes:
    nonce = secrets.token_bytes(NONCE_BYTES)
    cipher = AESGCM(_derive(key))
    return nonce + cipher.encrypt(nonce, normalize_email(email).encode(), EMAIL_AAD)


def decrypt_email(ciphertext: bytes, *, key: str) -> str:
    if len(ciphertext) <= NONCE_BYTES:
        raise ValueError("Could not decrypt the stored address.")
    nonce, payload = ciphertext[:NONCE_BYTES], ciphertext[NONCE_BYTES:]
    try:
        return AESGCM(_derive(key)).decrypt(nonce, payload, EMAIL_AAD).decode()
    except InvalidTag as exc:
        raise ValueError("Could not decrypt the stored address.") from exc


def _mask_part(part: str) -> str:
    if not part:
        return ""
    return part[0] + MASK_CHARACTER * MASK_WIDTH


def mask_email(email: str) -> str:
    normalized = normalize_email(email)
    if "@" not in normalized:
        return _mask_part(normalized)

    local, domain = normalized.split("@", 1)
    if "." in domain:
        name, suffix = domain.split(".", 1)
        return f"{_mask_part(local)}@{_mask_part(name)}.{suffix}"
    return f"{_mask_part(local)}@{_mask_part(domain)}"


def new_otp(digits: int = 6) -> str:
    return "".join(secrets.choice("0123456789") for _ in range(digits))


def hash_otp(otp: str, *, secret: str) -> str:
    return hmac.new(_derive(secret), otp.encode(), hashlib.sha256).hexdigest()


def constant_time_equals(left: str, right: str) -> bool:
    return hmac.compare_digest(left, right)
