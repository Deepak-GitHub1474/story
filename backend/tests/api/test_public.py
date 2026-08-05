async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def publish(client, headers, body="A story anyone may read.", title="A quiet year"):
    story = (
        await client.post("/v1/stories", json={"title": title, "body": body}, headers=headers)
    ).json()["data"]["story"]
    published = await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return published.json()["data"]["story"]


async def test_a_public_story_is_readable_without_signing_in(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)

    response = await client.get(f"/v1/public/stories/{story['slug']}")
    assert response.status_code == 200
    assert response.json()["data"]["story"]["title"] == "A quiet year"


async def test_the_public_story_carries_its_body(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers, body="The whole text belongs here.")

    data = (await client.get(f"/v1/public/stories/{story['slug']}")).json()["data"]
    assert data["story"]["body"] == "The whole text belongs here."


async def test_the_public_story_names_its_author_without_an_id(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)

    author = (await client.get(f"/v1/public/stories/{story['slug']}")).json()["data"]["story"][
        "author"
    ]
    assert author["display_name"] == signup_payload["username"]
    assert "user_id" not in author


async def test_a_private_story_is_not_public(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (
        await client.post("/v1/stories", json={"body": "Mine alone."}, headers=headers)
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "private"},
        headers=headers,
    )

    response = await client.get("/v1/public/stories/anything")
    assert response.status_code == 404


async def test_an_unknown_slug_is_404(client):
    response = await client.get("/v1/public/stories/not-a-real-slug")
    assert response.status_code == 404


async def test_an_unpublished_story_disappears_from_the_public_page(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)
    await client.post(f"/v1/stories/{story['story_id']}/unpublish", headers=headers)

    response = await client.get(f"/v1/public/stories/{story['slug']}")
    assert response.status_code == 404


async def test_a_deleted_story_disappears_from_the_public_page(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)
    await client.delete(f"/v1/stories/{story['story_id']}", headers=headers)

    response = await client.get(f"/v1/public/stories/{story['slug']}")
    assert response.status_code == 404


async def test_the_public_story_reports_reading_time_and_counts(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)

    data = (await client.get(f"/v1/public/stories/{story['slug']}")).json()["data"]["story"]
    assert data["reading_minutes"] >= 1
    assert data["counts"]["likes"] == 0


async def test_the_public_endpoint_never_leaks_the_authors_email(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)

    response = await client.get(f"/v1/public/stories/{story['slug']}")
    assert "email" not in response.text.lower()


async def test_a_blocked_authors_story_is_not_public(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers)

    await app_instance.state.mongo_db["users"].update_one(
        {"username_lower": signup_payload["username"]}, {"$set": {"blocked": True}}
    )

    response = await client.get(f"/v1/public/stories/{story['slug']}")
    assert response.status_code == 404
