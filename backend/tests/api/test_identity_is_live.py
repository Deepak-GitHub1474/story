"""A person's face and name belong to the person, not to the rows they left behind.

Rename yourself, or roll a new face, and every surface that shows you must
follow — the story you wrote last year, the comment you left this morning,
the like sitting under someone else's post.
"""


async def headers_for(client, payload, username: str) -> dict:
    tokens = (await client.post("/v1/auth/signup", json={**payload, "username": username})).json()[
        "data"
    ]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def a_public_story(client, headers, **extra) -> dict:
    story = (
        await client.post(
            "/v1/stories",
            json={"title": "Ordinary ground", "body": "x" * 80, **extra},
            headers=headers,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story


async def rename(client, headers, display_name: str) -> str:
    body = (
        await client.patch(
            "/v1/users/me", json={"display_name": display_name}, headers=headers
        )
    ).json()
    return body["data"]["user"]["display_name"]


async def new_face(client, headers) -> str:
    body = (await client.post("/v1/users/me/avatar/regenerate", headers=headers)).json()
    return body["data"]["user"]["avatar_seed"]


async def test_the_face_on_a_story_follows_its_author(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story = await a_public_story(client, mine)

    seed = await new_face(client, mine)

    shown = (
        await client.get(f"/v1/stories/{story['story_id']}", headers=mine)
    ).json()["data"]["story"]

    assert shown["author"]["avatar_seed"] == seed


async def test_the_name_on_a_story_follows_its_author(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story = await a_public_story(client, mine)

    name = await rename(client, mine, "Wren")

    shown = (
        await client.get(f"/v1/stories/{story['story_id']}", headers=mine)
    ).json()["data"]["story"]

    assert shown["author"]["display_name"] == name


async def test_a_listing_shows_the_author_as_they_are_now(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    await a_public_story(client, mine)

    seed = await new_face(client, mine)
    name = await rename(client, mine, "Wren")

    items = (
        await client.get("/v1/users/the_writer/stories", headers=mine)
    ).json()["data"]["items"]

    assert items[0]["author"]["avatar_seed"] == seed
    assert items[0]["author"]["display_name"] == name


async def test_the_face_on_a_comment_follows_its_author(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "a_reader")
    story = await a_public_story(client, mine)
    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Good one."},
        headers=reader,
    )

    seed = await new_face(client, reader)

    items = (
        await client.get(f"/v1/stories/{story['story_id']}/comments", headers=mine)
    ).json()["data"]["items"]

    assert items[0]["author"]["avatar_seed"] == seed


async def test_the_face_on_a_reply_follows_its_author(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "a_reader")
    story = await a_public_story(client, mine)
    parent = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Good one."},
            headers=mine,
        )
    ).json()["data"]["comment"]
    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Agreed.", "parent_id": parent["comment_id"]},
        headers=reader,
    )

    seed = await new_face(client, reader)

    items = (
        await client.get(f"/v1/comments/{parent['comment_id']}/replies", headers=mine)
    ).json()["data"]["items"]

    assert items[0]["author"]["avatar_seed"] == seed


async def test_a_face_in_the_liked_by_row_follows_its_owner(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "a_reader")
    story = await a_public_story(client, mine)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    seed = await new_face(client, reader)

    shown = (
        await client.get(f"/v1/stories/{story['story_id']}", headers=mine)
    ).json()["data"]["story"]

    assert shown["liked_by"][0]["avatar_seed"] == seed


async def test_the_face_on_an_activity_row_follows_the_actor(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "a_reader")
    story = await a_public_story(client, mine)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    seed = await new_face(client, reader)
    name = await rename(client, reader, "Wren")

    items = (await client.get("/v1/notifications", headers=mine)).json()["data"]["items"]

    assert items[0]["actor"]["avatar_seed"] == seed
    assert items[0]["actor"]["display_name"] == name


async def test_the_card_on_a_reshare_follows_the_original_author(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    sharer = await headers_for(client, signup_payload, "the_sharer")
    source = await a_public_story(client, mine)
    reshare = await a_public_story(client, sharer, shared_story_id=source["story_id"])

    seed = await new_face(client, mine)

    shown = (
        await client.get(f"/v1/stories/{reshare['story_id']}", headers=sharer)
    ).json()["data"]["story"]

    assert shown["shared"]["author"]["avatar_seed"] == seed


async def test_the_public_page_shows_the_author_as_they_are_now(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    story = await a_public_story(client, mine)
    slug = (
        await client.get(f"/v1/stories/{story['story_id']}", headers=mine)
    ).json()["data"]["story"]["slug"]

    seed = await new_face(client, mine)
    name = await rename(client, mine, "Wren")

    shown = (await client.get(f"/v1/public/stories/{slug}")).json()["data"]["story"]

    assert shown["author"]["avatar_seed"] == seed
    assert shown["author"]["display_name"] == name


async def test_search_results_show_the_author_as_they_are_now(client, signup_payload):
    mine = await headers_for(client, signup_payload, "the_writer")
    await a_public_story(client, mine)

    seed = await new_face(client, mine)

    found = (
        await client.get("/v1/search?q=Ordinary", headers=mine)
    ).json()["data"]["stories"]

    assert found, "the story must be findable for this to mean anything"
    assert found[0]["author"]["avatar_seed"] == seed
