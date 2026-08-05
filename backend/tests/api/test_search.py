import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def publish(client, headers, body, title=None):
    story = (
        await client.post("/v1/stories", json={"title": title, "body": body}, headers=headers)
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story


@pytest.fixture
def writer():
    return account("searchable_one")


async def test_search_requires_a_query(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/search?q=", headers=headers)
    assert response.status_code == 422


async def test_search_finds_a_user_by_username(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    await signup(client, writer)

    data = (await client.get("/v1/search?q=searchable", headers=headers)).json()["data"]
    assert any(item["username"] == writer["username"] for item in data["users"])


async def test_search_finds_a_user_by_display_name(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    writer_headers = await auth_headers(client, writer)
    await client.patch("/v1/users/me", json={"display_name": "Quiet Fox"}, headers=writer_headers)

    data = (await client.get("/v1/search?q=quiet fox", headers=headers)).json()["data"]
    assert any(item["display_name"] == "Quiet Fox" for item in data["users"])


async def test_search_excludes_yourself_from_people(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    data = (await client.get(f"/v1/search?q={signup_payload['username']}", headers=headers)).json()[
        "data"
    ]
    assert all(item["username"] != signup_payload["username"] for item in data["users"])


async def test_search_finds_communities(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    data = (await client.get("/v1/search?q=grief", headers=headers)).json()["data"]
    assert data["communities"]
    assert all(
        "grief" in item["name"].lower() or "grief" in item["slug"] for item in data["communities"]
    )


async def test_search_finds_public_stories(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    writer_headers = await auth_headers(client, writer)
    await publish(client, writer_headers, "A story about lighthouses and fog.")

    data = (await client.get("/v1/search?q=lighthouses", headers=headers)).json()["data"]
    assert any("lighthouse" in item["excerpt"].lower() for item in data["stories"])


async def test_search_never_returns_a_draft(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    writer_headers = await auth_headers(client, writer)
    await client.post(
        "/v1/stories",
        json={"body": "Secret draft about aardvarks."},
        headers=writer_headers,
    )

    data = (await client.get("/v1/search?q=aardvarks", headers=headers)).json()["data"]
    assert data["stories"] == []


async def test_search_never_returns_a_private_story(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    writer_headers = await auth_headers(client, writer)
    story = (
        await client.post(
            "/v1/stories",
            json={"body": "Private words about zeppelins."},
            headers=writer_headers,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "private"},
        headers=writer_headers,
    )

    data = (await client.get("/v1/search?q=zeppelins", headers=headers)).json()["data"]
    assert data["stories"] == []


async def test_search_can_be_scoped_to_one_kind(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    await signup(client, writer)

    data = (await client.get("/v1/search?q=searchable&kind=users", headers=headers)).json()["data"]
    assert data["users"]
    assert data["communities"] == []
    assert data["stories"] == []


async def test_search_is_case_insensitive(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    await signup(client, writer)
    data = (await client.get("/v1/search?q=SEARCHABLE", headers=headers)).json()["data"]
    assert data["users"]


async def test_search_escapes_regex_characters(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/search?q=%5B%5E a%2B", headers=headers)
    assert response.status_code == 200


async def test_search_excludes_blocked_people(client, signup_payload, writer):
    headers = await auth_headers(client, signup_payload)
    await signup(client, writer)
    await client.post(f"/v1/connections/{writer['username']}/block", headers=headers)

    data = (await client.get("/v1/search?q=searchable", headers=headers)).json()["data"]
    assert all(item["username"] != writer["username"] for item in data["users"])


async def test_share_returns_a_url_with_the_slug(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers, "Something worth passing on.")

    response = await client.post(f"/v1/stories/{story['story_id']}/share", headers=headers)
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["url"].endswith(data["slug"])
    assert data["shares"] == 1


async def test_share_never_leaks_the_user_id(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await publish(client, headers, "Nothing identifying here.")
    data = (await client.post(f"/v1/stories/{story['story_id']}/share", headers=headers)).json()[
        "data"
    ]

    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    assert me["user_id"] not in data["url"]


async def test_a_private_story_cannot_be_shared(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await client.post("/v1/stories", json={"body": "Mine only."}, headers=headers)).json()[
        "data"
    ]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "private"},
        headers=headers,
    )

    response = await client.post(f"/v1/stories/{story['story_id']}/share", headers=headers)
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "STORY_NOT_SHAREABLE"
