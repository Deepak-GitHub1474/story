import re

LINK_PATTERN = re.compile(r"(https?://|www\.|\b[\w-]+\.(com|net|org|io|co|in|me)\b)", re.I)


def contains_link(text: str) -> bool:
    return bool(LINK_PATTERN.search(text))


def serialize_public_user(doc: dict, *, is_following: bool = False, is_me: bool = False) -> dict:
    return {
        "is_following": is_following,
        "is_me": is_me,
        "user_id": doc["_id"],
        "username": doc["username"],
        "display_name": doc["display_name"],
        "avatar_seed": doc["avatar_seed"],
        "bio": doc.get("bio"),
        "interests": doc.get("interests", []),
        "counts": doc.get("counts", {}),
    }
