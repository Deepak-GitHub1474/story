NAMESPACE = "ST"


def refresh_token(token_hash: str) -> str:
    return f"{NAMESPACE}:RT:{token_hash}"


def revoked_refresh(token_hash: str) -> str:
    return f"{NAMESPACE}:RT_REVOKED:{token_hash}"


def refresh_family(family_id: str) -> str:
    return f"{NAMESPACE}:RT_FAMILY:{family_id}"


def access_denylist(jti: str) -> str:
    return f"{NAMESPACE}:JWT_DENY:{jti}"


def user_sessions(user_id: str) -> str:
    return f"{NAMESPACE}:USER_SESSIONS:{user_id}"


def rate_limit(scope: str, identity: str) -> str:
    return f"{NAMESPACE}:RL:{scope}:{identity}"


def username_lock(username: str) -> str:
    return f"{NAMESPACE}:LOCK:USERNAME:{username}"


def email_otp(user_id: str) -> str:
    return f"{NAMESPACE}:OTP:{user_id}"


def otp_cooldown(user_id: str) -> str:
    return f"{NAMESPACE}:OTP_CD:{user_id}"


def reset_otp(user_id: str) -> str:
    return f"{NAMESPACE}:RESET_OTP:{user_id}"


def reset_cooldown(user_id: str) -> str:
    return f"{NAMESPACE}:RESET_CD:{user_id}"


def reset_token(token_hash: str) -> str:
    return f"{NAMESPACE}:RESET_TOKEN:{token_hash}"


def session_epoch(user_id: str) -> str:
    return f"{NAMESPACE}:SESSION_EPOCH:{user_id}"


def totp_used(user_id: str, code: str) -> str:
    return f"{NAMESPACE}:TOTP_USED:{user_id}:{code}"


def presence(user_id: str) -> str:
    return f"{NAMESPACE}:PRESENCE:{user_id}"


def typing(conversation_id: str, user_id: str) -> str:
    return f"{NAMESPACE}:TYPING:{conversation_id}:{user_id}"
