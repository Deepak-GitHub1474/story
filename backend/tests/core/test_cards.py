"""One place asks who someone is, so there is one answer and it is current."""

import pytest
import pytest_asyncio

from app.core.cards import GONE_NAME, card_for, cards, top_up


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


@pytest.fixture
def person():
    def build(user_id: str, **extra):
        return {
            "_id": user_id,
            "username": user_id,
            "username_lower": user_id,
            "referral_code": user_id,
            "display_name": user_id.title(),
            "avatar_seed": "a" * 16,
            **extra,
        }

    return build


async def test_a_card_carries_the_three_things_a_face_needs(mongo, person):
    await mongo["users"].insert_one(person("wren"))

    people = await cards(["wren"], mongo=mongo)

    assert people["wren"] == {
        "user_id": "wren",
        "username": "wren",
        "display_name": "Wren",
        "avatar_seed": "a" * 16,
    }


async def test_asking_twice_for_the_same_person_costs_one_answer(mongo, person):
    await mongo["users"].insert_one(person("wren"))

    people = await cards(["wren", "wren", "wren"], mongo=mongo)

    assert list(people) == ["wren"]


async def test_asking_for_nobody_touches_nothing(mongo):
    assert await cards([], mongo=mongo) == {}
    assert await cards([None, ""], mongo=mongo) == {}


async def test_a_stranger_reads_as_a_deleted_account(mongo):
    people = await cards(["ghost"], mongo=mongo)

    assert people == {}
    assert card_for(people, "ghost") == {
        "user_id": "ghost",
        "username": None,
        "display_name": GONE_NAME,
        "avatar_seed": "",
    }


async def test_a_stripped_row_reads_as_a_deleted_account(mongo):
    await mongo["users"].insert_one(
        {"_id": "gone", "username": "deleted_gone", "status": "deleted"}
    )

    people = await cards(["gone"], mongo=mongo)

    assert people["gone"]["display_name"] == GONE_NAME
    assert people["gone"]["username"] is None, "a tombstone is not a handle to tap"
    assert people["gone"]["avatar_seed"] == ""


async def test_topping_up_keeps_what_was_already_known(mongo, person):
    await mongo["users"].insert_many([person("wren"), person("ash")])
    known = await cards(["wren"], mongo=mongo)

    people = await top_up(known, ["wren", "ash"], mongo=mongo)

    assert set(people) == {"wren", "ash"}
    assert known == {"wren": known["wren"]}, "the map handed in is left alone"


async def test_topping_up_with_nothing_missing_returns_the_same_map(mongo, person):
    await mongo["users"].insert_one(person("wren"))
    known = await cards(["wren"], mongo=mongo)

    assert await top_up(known, ["wren"], mongo=mongo) is known
