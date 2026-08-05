from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

ARGON2_MEMORY_KIB = 65536
ARGON2_ITERATIONS = 3
ARGON2_PARALLELISM = 2
ARGON2_HASH_LENGTH = 32
ARGON2_SALT_LENGTH = 16

PASSWORD_MIN_LENGTH = 10

_hasher = PasswordHasher(
    time_cost=ARGON2_ITERATIONS,
    memory_cost=ARGON2_MEMORY_KIB,
    parallelism=ARGON2_PARALLELISM,
    hash_len=ARGON2_HASH_LENGTH,
    salt_len=ARGON2_SALT_LENGTH,
)

_BREACHED: frozenset[str] = frozenset(
    {
        "password",
        "password1",
        "password123",
        "12345678",
        "123456789",
        "qwertyuiop",
        "iloveyou",
        "letmein123",
        "adminadmin",
        "welcome123",
    }
)


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def needs_rehash(password_hash: str) -> bool:
    try:
        return _hasher.check_needs_rehash(password_hash)
    except InvalidHashError:
        return True


def validate_password_strength(password: str, *, username: str) -> None:
    if len(password) < PASSWORD_MIN_LENGTH:
        raise ValueError(f"Password must be at least {PASSWORD_MIN_LENGTH} characters.")
    if username and username.casefold() in password.casefold():
        raise ValueError("Password must not contain your username.")
    if password.casefold() in _BREACHED:
        raise ValueError("That password is too common. Choose another.")
