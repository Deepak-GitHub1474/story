import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote, urlencode

STEP_SECONDS = 30
DIGITS = 6
DRIFT_STEPS = 1
SECRET_BYTES = 20
BACKUP_CODE_COUNT = 8
BACKUP_CODE_LENGTH = 10
BACKUP_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789"


def new_secret() -> str:
    return base64.b32encode(secrets.token_bytes(SECRET_BYTES)).decode()


def code_at(secret: str, moment: int) -> str:
    key = base64.b32decode(secret)
    counter = struct.pack(">Q", moment // STEP_SECONDS)
    digest = hmac.new(key, counter, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    truncated = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(truncated % 10**DIGITS).zfill(DIGITS)


def verify(secret: str, code: str | None, *, at: int | None = None) -> bool:
    if not code or len(code) != DIGITS or not code.isdigit():
        return False

    moment = int(time.time()) if at is None else at
    for step in range(-DRIFT_STEPS, DRIFT_STEPS + 1):
        if hmac.compare_digest(code_at(secret, moment + step * STEP_SECONDS), code):
            return True
    return False


def provisioning_uri(secret: str, *, username: str, issuer: str) -> str:
    query = urlencode(
        {
            "secret": secret,
            "issuer": issuer,
            "algorithm": "SHA1",
            "digits": DIGITS,
            "period": STEP_SECONDS,
        }
    )
    label = f"{quote(issuer)}:{quote(username)}"
    return f"otpauth://totp/{label}?{query}"


def new_backup_codes() -> list[str]:
    return [
        "".join(secrets.choice(BACKUP_ALPHABET) for _ in range(BACKUP_CODE_LENGTH))
        for _ in range(BACKUP_CODE_COUNT)
    ]


def hash_backup_code(code: str, *, secret: str) -> str:
    key = hashlib.sha256(secret.encode()).digest()
    return hmac.new(key, code.strip().lower().encode(), hashlib.sha256).hexdigest()
