USERS = "users"
DEVICES = "devices"

USERNAME_PATTERN = r"^[a-z0-9][a-z0-9_-]*[a-z0-9]$|^[a-z0-9]{1}$"
USERNAME_FORBIDDEN = ("--",)
USERNAME_MIN_LENGTH = 2
USERNAME_MAX_LENGTH = 30

RESERVED_USERNAMES = frozenset(
    {
        "admin",
        "administrator",
        "moderator",
        "mod",
        "staff",
        "support",
        "help",
        "helpdesk",
        "security",
        "official",
        "story",
        "storyapp",
        "team",
        "root",
        "system",
        "api",
        "www",
        "mail",
        "email",
        "settings",
        "login",
        "signin",
        "signup",
        "logout",
        "vault",
        "chat",
        "search",
        "explore",
        "about",
        "terms",
        "privacy",
        "legal",
        "billing",
        "me",
        "you",
        "null",
        "undefined",
        "anonymous",
    }
)

REFERRAL_CODE_ATTEMPTS = 8

DEFAULT_PREFS = {
    "theme": "system",
    "reading_size": "reading",
    "notify_in_app": True,
    "notify_email": False,
}

DEFAULT_COUNTS = {"stories": 0, "connections": 0, "followers": 0, "communities": 0}

DEFAULT_ONBOARDING = {
    "interests_done": False,
    "first_story_done": False,
    "recovery_kit_offered": False,
}

TNC_VERSION = "2026-08-01"

PUBLIC_USER_PROJECTION = {
    "_id": 1,
    "username": 1,
    "display_name": 1,
    "avatar_seed": 1,
    "role": 1,
    "status": 1,
    "blocked": 1,
    "referral_code": 1,
    "referred_by": 1,
    "bio": 1,
    "interests": 1,
    "counts": 1,
    "prefs": 1,
    "onboarding": 1,
    "login_info": 1,
    "created_at": 1,
    "last_login_at": 1,
}
