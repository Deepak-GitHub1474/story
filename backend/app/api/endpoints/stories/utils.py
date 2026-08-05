import re
import secrets

from app.api.endpoints.stories.constants import EXCERPT_LENGTH, WORDS_PER_MINUTE
from app.core.time import to_wire

WHITESPACE = re.compile(r"\s+")


def build_excerpt(body: str) -> str:
    flattened = WHITESPACE.sub(" ", body).strip()
    if len(flattened) <= EXCERPT_LENGTH:
        return flattened
    return flattened[: EXCERPT_LENGTH - 1].rstrip() + "…"


def reading_minutes(body: str) -> int:
    words = len(WHITESPACE.sub(" ", body).strip().split())
    return max(1, round(words / WORDS_PER_MINUTE))


def new_slug() -> str:
    return secrets.token_urlsafe(9).replace("-", "").replace("_", "")[:12]


def serialize_story(doc: dict, *, include_body: bool, is_liked: bool = False) -> dict:
    snapshot = doc.get("author_snapshot", {})
    community = doc.get("community")
    payload = {
        "story_id": doc["_id"],
        "community": community,
        "author": {
            "user_id": doc.get("author_id"),
            "display_name": snapshot.get("display_name", "A deleted account"),
            "avatar_seed": snapshot.get("avatar_seed", ""),
            "username": snapshot.get("username"),
        },
        "title": doc.get("title"),
        "excerpt": doc.get("excerpt", ""),
        "visibility": doc["visibility"],
        "slug": doc.get("slug"),
        "counts": doc.get("counts", {}),
        "reading_minutes": doc.get("reading_minutes", 1),
        "is_liked": is_liked,
        "published_at": to_wire(doc.get("published_at")),
        "created_at": to_wire(doc.get("created_at")),
        "updated_at": to_wire(doc.get("updated_at")),
    }
    if include_body:
        payload["body"] = doc.get("body", "")
    return payload


def serialize_comment(doc: dict, *, is_liked: bool = False) -> dict:
    snapshot = doc.get("author_snapshot") or {}
    return {
        "comment_id": doc["_id"],
        "story_id": doc["story_id"],
        "parent_id": doc.get("parent_id"),
        "author": {
            "user_id": doc.get("author_id"),
            "display_name": snapshot.get("display_name", "A deleted account"),
            "avatar_seed": snapshot.get("avatar_seed", ""),
        },
        "body": doc["body"],
        "counts": doc.get("counts", {}),
        "is_liked": is_liked,
        "is_tombstone": doc.get("is_tombstone", False),
        "edited_at": to_wire(doc.get("edited_at")),
        "created_at": to_wire(doc.get("created_at")),
    }
