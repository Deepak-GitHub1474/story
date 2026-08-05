from dataclasses import dataclass, field
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.logging import get_logger

logger = get_logger("story.db.indexes")


@dataclass(frozen=True)
class IndexSpec:
    keys: list[tuple[str, int]]
    name: str
    unique: bool = False
    sparse: bool = False
    partial: dict[str, Any] | None = field(default=None)

    def to_model(self) -> IndexModel:
        options: dict[str, Any] = {"name": self.name}
        if self.unique:
            options["unique"] = True
        if self.sparse:
            options["sparse"] = True
        if self.partial:
            options["partialFilterExpression"] = self.partial
        return IndexModel(self.keys, **options)


INDEXES: dict[str, list[IndexSpec]] = {
    "users": [
        IndexSpec([("username_lower", ASCENDING)], "uq_username", unique=True),
        IndexSpec([("referral_code", ASCENDING)], "uq_referral_code", unique=True),
        IndexSpec(
            [("referred_by", ASCENDING), ("created_at", DESCENDING)],
            "ix_referred_by",
            sparse=True,
        ),
        IndexSpec(
            [("blocked", ASCENDING), ("created_at", DESCENDING)],
            "ix_blocked",
            partial={"blocked": True},
        ),
        IndexSpec([("status", ASCENDING), ("created_at", DESCENDING)], "ix_status_created"),
        IndexSpec([("interests", ASCENDING)], "ix_interests"),
        IndexSpec([("last_active_at", DESCENDING)], "ix_last_active", sparse=True),
    ],
    "user_keys": [
        IndexSpec([("user_id", ASCENDING)], "uq_user_keys_user", unique=True),
    ],
    "stories": [
        IndexSpec(
            [("author_id", ASCENDING), ("_id", DESCENDING)],
            "ix_author_recent",
            partial={"deleted_at": None},
        ),
        IndexSpec(
            [("author_id", ASCENDING), ("visibility", ASCENDING), ("_id", DESCENDING)],
            "ix_author_visibility",
        ),
        IndexSpec(
            [("visibility", ASCENDING), ("_id", DESCENDING)],
            "ix_feed",
            partial={"visibility": "public", "deleted_at": None},
        ),
        IndexSpec(
            [("slug", ASCENDING)],
            "uq_slug",
            unique=True,
            partial={"slug": {"$type": "string"}},
        ),
    ],
    "comments": [
        IndexSpec(
            [("story_id", ASCENDING), ("_id", ASCENDING)],
            "ix_story_thread",
            partial={"deleted_at": None},
        ),
        IndexSpec([("author_id", ASCENDING), ("_id", DESCENDING)], "ix_author_comments"),
    ],
    "reactions": [
        IndexSpec(
            [("target_kind", ASCENDING), ("target_id", ASCENDING), ("_id", DESCENDING)],
            "ix_target",
        ),
        IndexSpec([("user_id", ASCENDING), ("_id", DESCENDING)], "ix_user_reactions"),
    ],
    "notifications": [
        IndexSpec([("user_id", ASCENDING), ("_id", DESCENDING)], "ix_user_recent"),
        IndexSpec(
            [("user_id", ASCENDING), ("read_at", ASCENDING)],
            "ix_user_unread",
            partial={"read_at": None},
        ),
        IndexSpec(
            [("user_id", ASCENDING), ("dedupe_key", ASCENDING)],
            "uq_user_dedupe",
            unique=True,
        ),
    ],
    "devices": [
        IndexSpec(
            [("user_id", ASCENDING), ("fingerprint", ASCENDING)],
            "uq_user_device",
            unique=True,
        ),
        IndexSpec([("user_id", ASCENDING), ("last_seen_at", DESCENDING)], "ix_user_last_seen"),
    ],
}


async def ensure_indexes(db: AsyncIOMotorDatabase) -> dict[str, int]:
    applied: dict[str, int] = {}
    for collection, specs in INDEXES.items():
        if not specs:
            continue
        await db[collection].create_indexes([spec.to_model() for spec in specs])
        applied[collection] = len(specs)
        logger.info("indexes_ensured", service="mongodb", count=len(specs))
    return applied
