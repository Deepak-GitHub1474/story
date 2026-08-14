async def headers_for(client, payload, username: str) -> dict:
    tokens = (await client.post("/v1/auth/signup", json={**payload, "username": username})).json()[
        "data"
    ]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def a_public_story(client, headers) -> str:
    story = (
        await client.post("/v1/stories", json={"title": "Mine", "body": "x" * 80}, headers=headers)
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story["story_id"]


async def test_a_comment_says_who_wrote_it(client, signup_payload):
    writer = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "quiet_fox")
    story_id = await a_public_story(client, writer)

    await client.post(
        f"/v1/stories/{story_id}/comments", json={"body": "This said it"}, headers=reader
    )

    items = (await client.get(f"/v1/stories/{story_id}/comments", headers=writer)).json()["data"][
        "items"
    ]

    assert items[0]["author"]["username"] == "quiet_fox", (
        "the app shows the handle and opens that profile from it"
    )


async def test_the_story_author_can_take_down_a_comment(client, signup_payload):
    writer = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "quiet_fox")
    story_id = await a_public_story(client, writer)

    comment = (
        await client.post(
            f"/v1/stories/{story_id}/comments",
            json={"body": "Not welcome here"},
            headers=reader,
        )
    ).json()["data"]["comment"]

    response = await client.delete(f"/v1/comments/{comment['comment_id']}", headers=writer)

    assert response.status_code == 200
    left = (await client.get(f"/v1/stories/{story_id}/comments", headers=writer)).json()["data"][
        "items"
    ]
    assert left == []


async def test_a_stranger_cannot_take_down_someone_elses_comment(client, signup_payload):
    writer = await headers_for(client, signup_payload, "the_writer")
    reader = await headers_for(client, signup_payload, "quiet_fox")
    stranger = await headers_for(client, signup_payload, "passer_by")
    story_id = await a_public_story(client, writer)

    comment = (
        await client.post(f"/v1/stories/{story_id}/comments", json={"body": "Mine"}, headers=reader)
    ).json()["data"]["comment"]

    response = await client.delete(f"/v1/comments/{comment['comment_id']}", headers=stranger)

    assert response.status_code in (403, 404)
