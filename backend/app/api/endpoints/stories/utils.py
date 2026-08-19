import re
import secrets

from app.api.endpoints.stories.constants import EXCERPT_LENGTH, WORDS_PER_MINUTE
from app.core.cards import card_for
from app.core.time import to_wire

WHITESPACE = re.compile(r"\s+")


MARKUP = re.compile(r"\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_", re.DOTALL)
BULLET = re.compile(r"^\s*[-*\u2022]\s+", re.MULTILINE)
RULE = re.compile(r"^[ \t]*[-\u2013\u2014_*]{3,}[ \t]*$", re.MULTILINE)


def strip_markup(body: str) -> str:
    without_rules = RULE.sub("", body)
    without_bullets = BULLET.sub("", without_rules)
    return MARKUP.sub(lambda m: m.group(1) or m.group(2) or m.group(3) or "", without_bullets)


def build_excerpt(body: str) -> str:
    flattened = WHITESPACE.sub(" ", strip_markup(body)).strip()
    if len(flattened) <= EXCERPT_LENGTH:
        return flattened
    return flattened[: EXCERPT_LENGTH - 1].rstrip() + "…"


def reading_minutes(body: str) -> int:
    words = len(WHITESPACE.sub(" ", body).strip().split())
    return max(1, round(words / WORDS_PER_MINUTE))


def new_slug() -> str:
    return secrets.token_urlsafe(9).replace("-", "").replace("_", "")[:12]


def liker_ids(doc: dict) -> list[str]:
    """The people in a story's liked-by row, as ids.

    Rows written before identity moved to a reference hold a whole card here.
    The migration rewrites them, but a page served while it is still running
    must not fall over, so both shapes are read.
    """
    return [
        person.get("user_id") if isinstance(person, dict) else person
        for person in doc.get("likers") or []
    ]


def serialize_story(
    doc: dict, *, people: dict, include_body: bool, is_liked: bool = False
) -> dict:
    community = doc.get("community")
    payload = {
        "story_id": doc["_id"],
        "community": community,
        "author": card_for(people, doc.get("author_id")),
        "title": doc.get("title"),
        "excerpt": doc.get("excerpt", ""),
        "visibility": doc["visibility"],
        "slug": doc.get("slug"),
        "counts": doc.get("counts", {}),
        "liked_by": [card_for(people, user_id) for user_id in liker_ids(doc)],
        "reading_minutes": doc.get("reading_minutes", 1),
        "images": doc.get("images", []),
        "image_ratio": doc.get("image_ratio"),
        "image_fit": doc.get("image_fit") or "cover",
        "is_liked": is_liked,
        "published_at": to_wire(doc.get("published_at")),
        "scheduled_for": to_wire(doc.get("scheduled_for")),
        "edited_at": to_wire(doc.get("edited_at")),
        "created_at": to_wire(doc.get("created_at")),
        "updated_at": to_wire(doc.get("updated_at")),
    }
    if include_body:
        payload["body"] = doc.get("body", "")
    return payload


def serialize_comment(
    doc: dict, *, people: dict, is_liked: bool = False, can_delete: bool = False
) -> dict:
    return {
        "comment_id": doc["_id"],
        "story_id": doc["story_id"],
        "parent_id": doc.get("parent_id"),
        "author": card_for(people, doc.get("author_id")),
        "body": doc["body"],
        "counts": doc.get("counts", {}),
        "is_liked": is_liked,
        "can_delete": can_delete,
        "is_tombstone": doc.get("is_tombstone", False),
        "edited_at": to_wire(doc.get("edited_at")),
        "created_at": to_wire(doc.get("created_at")),
    }
