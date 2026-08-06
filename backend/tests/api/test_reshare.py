async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def published(client, headers, body="Something worth passing on."):
    story = (
        await client.post("/v1/stories", json={"body": body}, headers=headers)
    ).json()["data"]["story"]
    return (
        await client.post(
            f"/v1/stories/{story['story_id']}/publish",
            json={"visibility": "public"},
            headers=headers,
        )
    ).json()["data"]["story"]


async def test_a_public_story_can_be_reshared_with_your_own_words(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    original = await published(client, author)

    reader = await auth_headers(client, account("resharer_one"))
    response = await client.post(
        "/v1/stories",
        json={"body": "This said what I could not.", "shared_story_id": original["story_id"]},
        headers=reader,
    )

    assert response.status_code == 201
    assert response.json()["data"]["story"]["shared"]["story_id"] == original["story_id"]


async def test_the_reshare_carries_the_original_text(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    original = await published(client, author, body="The words that mattered.")

    reader = await auth_headers(client, account("resharer_two"))
    story = (
        await client.post(
            "/v1/stories",
            json={"body": "Read this.", "shared_story_id": original["story_id"]},
            headers=reader,
        )
    ).json()["data"]["story"]

    assert "The words that mattered" in story["shared"]["excerpt"]
    assert story["shared"]["author"]["username"] == signup_payload["username"]


async def test_your_own_words_are_separate_from_the_original(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    original = await published(client, author, body="Their words.")

    reader = await auth_headers(client, account("resharer_three"))
    story = (
        await client.post(
            "/v1/stories",
            json={"body": "My words.", "shared_story_id": original["story_id"]},
            headers=reader,
        )
    ).json()["data"]["story"]

    assert story["body"] == "My words."
    assert "Their words" not in story["body"]


async def test_resharing_bumps_the_original_share_count(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    original = await published(client, author)

    reader = await auth_headers(client, account("resharer_four"))
    await client.post(
        "/v1/stories",
        json={"body": "Passing it on.", "shared_story_id": original["story_id"]},
        headers=reader,
    )

    detail = (
        await client.get(f"/v1/stories/{original['story_id']}", headers=author)
    ).json()["data"]["story"]

    assert detail["counts"]["shares"] == 1


async def test_a_private_story_cannot_be_reshared(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    story = (
        await client.post("/v1/stories", json={"body": "Mine alone."}, headers=author)
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "private"},
        headers=author,
    )

    reader = await auth_headers(client, account("resharer_five"))
    response = await client.post(
        "/v1/stories",
        json={"body": "Look at this.", "shared_story_id": story["story_id"]},
        headers=reader,
    )

    assert response.status_code in (400, 403, 404)
    assert response.json()["data"]["code"] == "STORY_NOT_SHAREABLE"


async def test_an_unknown_story_cannot_be_reshared(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.post(
        "/v1/stories",
        json={"body": "Look.", "shared_story_id": "sto_01JJJJJJJJJJJJJJJJJJJJJJJJ"},
        headers=headers,
    )

    assert response.status_code == 404


async def test_a_reshare_with_no_words_of_your_own_is_allowed(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    original = await published(client, author)

    reader = await auth_headers(client, account("resharer_six"))
    response = await client.post(
        "/v1/stories",
        json={"body": "", "shared_story_id": original["story_id"]},
        headers=reader,
    )

    assert response.status_code == 201


async def test_a_reshare_of_a_reshare_points_at_the_original(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    original = await published(client, author)

    first = await auth_headers(client, account("resharer_seven"))
    middle = (
        await client.post(
            "/v1/stories",
            json={"body": "Passing on.", "shared_story_id": original["story_id"]},
            headers=first,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{middle['story_id']}/publish",
        json={"visibility": "public"},
        headers=first,
    )

    second = await auth_headers(client, account("resharer_eight"))
    story = (
        await client.post(
            "/v1/stories",
            json={"body": "And again.", "shared_story_id": middle["story_id"]},
            headers=second,
        )
    ).json()["data"]["story"]

    assert story["shared"]["story_id"] == original["story_id"]
