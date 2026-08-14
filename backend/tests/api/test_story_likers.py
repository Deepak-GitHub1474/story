from app.api.endpoints.stories.constants import LIKERS_PREVIEW


async def headers_for(client, payload, username: str) -> dict:
    tokens = (await client.post("/v1/auth/signup", json={**payload, "username": username})).json()[
        "data"
    ]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def a_public_story(client, headers) -> str:
    story = (
        await client.post(
            "/v1/stories",
            json={"title": "Ordinary ground", "body": "x" * 80},
            headers=headers,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story["story_id"]


async def test_a_story_carries_the_faces_of_its_newest_likes(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story_id = await a_public_story(client, mine)

    for index in range(4):
        reader = await headers_for(client, signup_payload, f"reader_{index}")
        await client.post(f"/v1/stories/{story_id}/like", headers=reader)

    story = (await client.get(f"/v1/stories/{story_id}", headers=mine)).json()["data"]["story"]

    assert len(story["liked_by"]) == LIKERS_PREVIEW, "three faces, however big the crowd"
    assert story["counts"]["likes"] == 4
    assert [person["username"] for person in story["liked_by"]] == [
        "reader_3",
        "reader_2",
        "reader_1",
    ], "the newest like leads, the same way for every story"


async def test_taking_a_like_back_takes_the_face_with_it(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story_id = await a_public_story(client, mine)

    reader = await headers_for(client, signup_payload, "one_reader")
    await client.post(f"/v1/stories/{story_id}/like", headers=reader)
    await client.delete(f"/v1/stories/{story_id}/like", headers=reader)

    story = (await client.get(f"/v1/stories/{story_id}", headers=mine)).json()["data"]["story"]

    assert story["liked_by"] == []
    assert story["counts"]["likes"] == 0


async def test_a_gap_in_the_three_is_filled_from_behind(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story_id = await a_public_story(client, mine)

    readers = {}
    for index in range(4):
        readers[index] = await headers_for(client, signup_payload, f"reader_{index}")
        await client.post(f"/v1/stories/{story_id}/like", headers=readers[index])

    await client.delete(f"/v1/stories/{story_id}/like", headers=readers[3])

    story = (await client.get(f"/v1/stories/{story_id}", headers=mine)).json()["data"]["story"]

    assert len(story["liked_by"]) == LIKERS_PREVIEW, "the fourth person steps forward"
    assert "reader_3" not in [person["username"] for person in story["liked_by"]]


async def test_the_feed_shows_the_faces_without_asking_again(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story_id = await a_public_story(client, mine)

    reader = await headers_for(client, signup_payload, "one_reader")
    await client.post(f"/v1/stories/{story_id}/like", headers=reader)

    feed = (await client.get("/v1/stories/mine", headers=mine)).json()["data"]["items"]
    posted = next(item for item in feed if item["story_id"] == story_id)

    assert [person["username"] for person in posted["liked_by"]] == ["one_reader"]


async def test_the_list_says_who_you_already_follow(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story_id = await a_public_story(client, mine)

    known = await headers_for(client, signup_payload, "an_old_friend")
    stranger = await headers_for(client, signup_payload, "a_new_face")
    await client.post(f"/v1/stories/{story_id}/like", headers=known)
    await client.post(f"/v1/stories/{story_id}/like", headers=stranger)
    await client.post(f"/v1/stories/{story_id}/like", headers=mine)
    await client.post("/v1/connections/an_old_friend", headers=mine)

    items = (await client.get(f"/v1/stories/{story_id}/likes", headers=mine)).json()["data"][
        "items"
    ]
    by_name = {person["username"]: person for person in items}

    assert by_name["an_old_friend"]["is_following"] is True
    assert by_name["a_new_face"]["is_following"] is False
    assert by_name["the_writer"]["is_me"] is True, "no follow button against yourself"
    assert by_name["an_old_friend"]["is_me"] is False


async def test_everyone_who_liked_it_can_be_listed(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story_id = await a_public_story(client, mine)

    for index in range(5):
        reader = await headers_for(client, signup_payload, f"reader_{index}")
        await client.post(f"/v1/stories/{story_id}/like", headers=reader)

    page = (await client.get(f"/v1/stories/{story_id}/likes?limit=3", headers=mine)).json()["data"]

    assert len(page["items"]) == 3
    assert page["has_more"] is True
    assert page["next_cursor"]

    rest = (
        await client.get(
            f"/v1/stories/{story_id}/likes?limit=3&cursor={page['next_cursor']}",
            headers=mine,
        )
    ).json()["data"]

    assert len(rest["items"]) == 2
    assert rest["has_more"] is False
    seen = [person["username"] for person in page["items"] + rest["items"]]
    assert len(set(seen)) == 5, "nobody is listed twice across the pages"


async def test_a_private_story_keeps_its_likes_to_itself(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story = (
        await client.post(
            "/v1/stories",
            json={"title": "Just for me", "body": "x" * 80},
            headers=mine,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "private"},
        headers=mine,
    )

    stranger = await headers_for(client, signup_payload, "a_stranger")
    response = await client.get(f"/v1/stories/{story['story_id']}/likes", headers=stranger)

    assert response.status_code == 404
