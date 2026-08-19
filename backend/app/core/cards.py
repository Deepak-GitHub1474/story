"""Who someone is, read from the one row that knows.

A story, a comment, a like and an activity row all name a person by id.
Nobody keeps a copy of their name or their face, so nobody can be wrong
about it. This is the single place that turns ids into something to draw.
"""

from collections.abc import Iterable
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

USERS = "users"
CARD_PROJECTION = {"username": 1, "display_name": 1, "avatar_seed": 1}
GONE_NAME = "A deleted account"


def blank_card(user_id: str | None = None) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "username": None,
        "display_name": GONE_NAME,
        "avatar_seed": "",
    }


def _card(doc: dict[str, Any]) -> dict[str, Any]:
    if not doc.get("display_name"):
        return blank_card(doc["_id"])
    return {
        "user_id": doc["_id"],
        "username": doc.get("username"),
        "display_name": doc["display_name"],
        "avatar_seed": doc.get("avatar_seed") or "",
    }


async def cards(
    user_ids: Iterable[str | None], *, mongo: AsyncIOMotorDatabase
) -> dict[str, dict[str, Any]]:
    wanted = {user_id for user_id in user_ids if user_id}
    if not wanted:
        return {}

    docs = (
        await mongo[USERS]
        .find({"_id": {"$in": list(wanted)}}, CARD_PROJECTION)
        .to_list(length=len(wanted))
    )
    return {doc["_id"]: _card(doc) for doc in docs}


async def top_up(
    people: dict[str, dict[str, Any]],
    user_ids: Iterable[str | None],
    *,
    mongo: AsyncIOMotorDatabase,
) -> dict[str, dict[str, Any]]:
    missing = {user_id for user_id in user_ids if user_id and user_id not in people}
    if not missing:
        return people
    return {**people, **await cards(missing, mongo=mongo)}


def card_for(people: dict[str, dict[str, Any]], user_id: str | None) -> dict[str, Any]:
    return people.get(user_id or "") or blank_card(user_id)
