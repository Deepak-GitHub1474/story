"""A page costs the same whether it holds one story or many.

Identity now comes from a look-up rather than a copy, so the thing to
protect is that the look-up stays one query for the whole page. If it ever
becomes one per row, this test says so before a feed does.
"""

import pytest
import pytest_asyncio

from app.api.endpoints.stories import controllers

READS = ("find", "find_one", "distinct", "count_documents", "aggregate")


class CountingCollection:
    def __init__(self, collection, tally):
        self._collection = collection
        self._tally = tally

    def __getattr__(self, name):
        attribute = getattr(self._collection, name)
        if name in READS:
            def counted(*args, **kwargs):
                self._tally.reads += 1
                return attribute(*args, **kwargs)

            return counted
        return attribute


class CountingDatabase:
    def __init__(self, database):
        self._database = database
        self.reads = 0

    def __getitem__(self, name):
        return CountingCollection(self._database[name], self)


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


class Claims:
    def __init__(self, user_id):
        self.user_id = user_id


async def headers_for(client, payload, username: str) -> dict:
    tokens = (await client.post("/v1/auth/signup", json={**payload, "username": username})).json()[
        "data"
    ]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def a_published_story(client, headers) -> str:
    story = (
        await client.post(
            "/v1/stories", json={"title": "Ground", "body": "x" * 80}, headers=headers
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story["story_id"]


async def reads_for_a_page_of(count: int, client, signup_payload, mongo) -> int:
    """A page of `count` stories, each liked by a different person.

    Distinct people matter: with one author and one liker a per-row look-up
    is indistinguishable from a batched one.
    """
    mine = await headers_for(client, signup_payload, f"writer_{count}")
    for index in range(count):
        story_id = await a_published_story(client, mine)
        reader = await headers_for(client, signup_payload, f"reader_{count}_{index}")
        await client.post(f"/v1/stories/{story_id}/like", headers=reader)

    me = (await client.get("/v1/auth/me", headers=mine)).json()["data"]["user"]["user_id"]
    counting = CountingDatabase(mongo)
    await controllers.list_mine(
        claims=Claims(me), mongo=counting, visibility=None, limit=20, cursor=None
    )
    return counting.reads


@pytest.mark.parametrize("count", [1, 6])
async def test_a_page_of_stories_costs_three_reads(count, client, signup_payload, mongo):
    assert await reads_for_a_page_of(count, client, signup_payload, mongo) == 3, (
        "one for the stories, one for what the reader liked, one for the faces"
    )
