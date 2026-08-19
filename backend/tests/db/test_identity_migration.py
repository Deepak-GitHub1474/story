"""Rows written under the old shape are brought over, once, and safely.

The reader must survive the gap: a story still holding the old liker
shape is served correctly while the migration is still running.
"""

import pytest
import pytest_asyncio

from app.api.endpoints.stories.utils import liker_ids, serialize_story
from app.db.backfill import IDENTITY_MARK, MIGRATIONS, backfill_identity


@pytest_asyncio.fixture
async def mongo(app_instance):
    db = app_instance.state.mongo_db
    await db[MIGRATIONS].delete_one({"_id": IDENTITY_MARK})
    return db


@pytest.fixture
def old_story():
    return {
        "_id": "sto_old",
        "author_id": "usr_writer",
        "author_snapshot": {
            "display_name": "Stale",
            "avatar_seed": "b" * 16,
            "username": "stale",
        },
        "visibility": "public",
        "likers": [
            {"user_id": "usr_a", "display_name": "Stale A", "avatar_seed": "c" * 16},
            {"user_id": "usr_b", "display_name": "Stale B", "avatar_seed": "d" * 16},
        ],
    }


async def test_a_story_keeps_who_liked_it_and_drops_the_copy(mongo, old_story):
    await mongo["stories"].insert_one(old_story)

    await backfill_identity(mongo)

    story = await mongo["stories"].find_one({"_id": "sto_old"})
    assert story["likers"] == ["usr_a", "usr_b"]
    assert "author_snapshot" not in story


async def test_a_comment_drops_the_copy(mongo):
    await mongo["comments"].insert_one(
        {"_id": "cmt_old", "author_id": "usr_a", "author_snapshot": {"display_name": "Stale"}}
    )

    await backfill_identity(mongo)

    assert "author_snapshot" not in await mongo["comments"].find_one({"_id": "cmt_old"})


async def test_an_activity_row_drops_the_copy(mongo):
    await mongo["notifications"].insert_one(
        {"_id": "not_old", "actor_id": "usr_a", "actor_snapshot": {"display_name": "Stale"}}
    )

    await backfill_identity(mongo)

    assert "actor_snapshot" not in await mongo["notifications"].find_one({"_id": "not_old"})


async def test_running_it_twice_leaves_the_same_rows(mongo, old_story):
    await mongo["stories"].insert_one(old_story)
    await backfill_identity(mongo)
    await mongo[MIGRATIONS].delete_one({"_id": IDENTITY_MARK})

    await backfill_identity(mongo)

    story = await mongo["stories"].find_one({"_id": "sto_old"})
    assert story["likers"] == ["usr_a", "usr_b"], "ids stay ids"


async def test_a_story_with_no_likes_is_not_given_an_empty_list(mongo):
    await mongo["stories"].insert_one(
        {"_id": "sto_quiet", "author_id": "usr_writer", "author_snapshot": {}}
    )

    await backfill_identity(mongo)

    assert "likers" not in await mongo["stories"].find_one({"_id": "sto_quiet"})


async def test_the_mark_stops_it_running_again(mongo, old_story):
    await mongo["stories"].insert_one(old_story)
    await backfill_identity(mongo)

    assert await backfill_identity(mongo) == 0


async def test_the_reader_survives_a_story_the_migration_has_not_reached(old_story):
    """A face still stored the old way must not take the page down."""
    assert liker_ids(old_story) == ["usr_a", "usr_b"]

    payload = serialize_story(old_story, people={}, include_body=False)

    assert [person["user_id"] for person in payload["liked_by"]] == ["usr_a", "usr_b"]
