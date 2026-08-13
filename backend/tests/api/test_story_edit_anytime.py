from datetime import timedelta

from app.core.time import utc_now


async def auth_headers(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def published(client, headers) -> dict:
    story = (
        await client.post(
            "/v1/stories",
            json={"title": "A first go", "body": "x" * 60},
            headers=headers,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story


async def test_an_old_story_can_still_be_corrected(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await published(client, headers)

    await app_instance.state.mongo_db["stories"].update_one(
        {"_id": story["story_id"]},
        {"$set": {"published_at": utc_now() - timedelta(days=30)}},
    )

    response = await client.patch(
        f"/v1/stories/{story['story_id']}",
        json={"title": "A better title"},
        headers=headers,
    )

    assert response.status_code == 200, "a writer owns their story for as long as it stands"
    assert response.json()["data"]["story"]["title"] == "A better title"


async def test_an_edit_after_publishing_is_marked(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await published(client, headers)

    await client.patch(
        f"/v1/stories/{story['story_id']}",
        json={"body": "y" * 80},
        headers=headers,
    )

    detail = (
        await client.get(f"/v1/stories/{story['story_id']}", headers=headers)
    ).json()["data"]["story"]

    assert detail["edited_at"], "the reader should be able to see it was revised"


async def test_a_draft_edit_is_not_marked_as_edited(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (
        await client.post(
            "/v1/stories",
            json={"title": "Still writing", "body": "x" * 60},
            headers=headers,
        )
    ).json()["data"]["story"]

    await client.patch(
        f"/v1/stories/{story['story_id']}",
        json={"body": "z" * 70},
        headers=headers,
    )

    detail = (
        await client.get(f"/v1/stories/{story['story_id']}", headers=headers)
    ).json()["data"]["story"]

    assert detail["edited_at"] is None, "nobody has read it yet, so nothing was revised"


async def test_a_stranger_still_cannot_edit_your_story(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    story = await published(client, mine)

    theirs = await auth_headers(
        client,
        {**signup_payload, "username": "someone_else"},
    )
    response = await client.patch(
        f"/v1/stories/{story['story_id']}",
        json={"title": "Mine now"},
        headers=theirs,
    )

    assert response.status_code in (403, 404)
