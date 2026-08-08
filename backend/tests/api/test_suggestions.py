async def auth_headers(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def set_interests(client, headers, slugs):
    return await client.patch("/v1/users/me", json={"interests": slugs}, headers=headers)


async def some_interests(client, headers, count=2):
    rows = (await client.get("/v1/interests", headers=headers)).json()["data"]["items"]
    return rows[:count]


async def suggestions(client, headers):
    response = await client.get("/v1/suggestions", headers=headers)
    assert response.status_code == 200
    return response.json()["data"]


async def test_a_new_account_still_gets_somewhere_to_go(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    data = await suggestions(client, headers)

    assert len(data["communities"]) > 0
    assert "members" in data["communities"][0]["counts"]
    assert data["communities"][0]["is_member"] is False


async def test_rooms_match_the_interests_you_picked(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    picked = await some_interests(client, headers, 1)
    await set_interests(client, headers, [picked[0]["slug"]])

    data = await suggestions(client, headers)

    assert data["communities"][0]["category_id"] == picked[0]["category_id"]


async def test_a_room_you_are_already_in_is_not_suggested(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    first = (await suggestions(client, headers))["communities"][0]["slug"]

    await client.post(f"/v1/communities/{first}/join", headers=headers)
    data = await suggestions(client, headers)

    assert first not in [row["slug"] for row in data["communities"]]


async def test_you_are_never_suggested_to_yourself(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    data = await suggestions(client, headers)

    assert signup_payload["username"] not in [row["username"] for row in data["people"]]


async def test_people_in_your_rooms_are_suggested(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    theirs = await auth_headers(client, account("suggest_neighbour"))

    room = (await suggestions(client, mine))["communities"][0]["slug"]
    for headers in (mine, theirs):
        await client.post(f"/v1/communities/{room}/join", headers=headers)

    story = (
        await client.post("/v1/stories", json={"body": "Hello from the room."}, headers=theirs)
    ).json()["data"]["story"]["story_id"]
    await client.post(
        f"/v1/stories/{story}/publish",
        json={"visibility": "public", "community_slug": room},
        headers=theirs,
    )

    data = await suggestions(client, mine)

    assert "suggest_neighbour" in [row["username"] for row in data["people"]]


async def test_someone_you_already_follow_is_not_suggested(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    theirs = await auth_headers(client, account("suggest_followed"))

    room = (await suggestions(client, mine))["communities"][0]["slug"]
    for headers in (mine, theirs):
        await client.post(f"/v1/communities/{room}/join", headers=headers)
    story = (
        await client.post("/v1/stories", json={"body": "Hello."}, headers=theirs)
    ).json()["data"]["story"]["story_id"]
    await client.post(
        f"/v1/stories/{story}/publish",
        json={"visibility": "public", "community_slug": room},
        headers=theirs,
    )

    await client.post("/v1/connections/suggest_followed", headers=mine)
    data = await suggestions(client, mine)

    assert "suggest_followed" not in [row["username"] for row in data["people"]]


async def test_someone_you_blocked_is_not_suggested(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    theirs = await auth_headers(client, account("suggest_blocked"))

    room = (await suggestions(client, mine))["communities"][0]["slug"]
    for headers in (mine, theirs):
        await client.post(f"/v1/communities/{room}/join", headers=headers)
    story = (
        await client.post("/v1/stories", json={"body": "Hello."}, headers=theirs)
    ).json()["data"]["story"]["story_id"]
    await client.post(
        f"/v1/stories/{story}/publish",
        json={"visibility": "public", "community_slug": room},
        headers=theirs,
    )

    await client.post("/v1/connections/suggest_blocked/block", headers=mine)
    data = await suggestions(client, mine)

    assert "suggest_blocked" not in [row["username"] for row in data["people"]]


async def test_suggestions_need_an_account(client):
    assert (await client.get("/v1/suggestions")).status_code == 401


async def test_someone_who_likes_the_same_thing_is_suggested(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    picked = await some_interests(client, mine, 1)
    await set_interests(client, mine, [picked[0]["slug"]])

    theirs = await auth_headers(client, account("same_taste"))
    await set_interests(client, theirs, [picked[0]["slug"]])

    data = await suggestions(client, mine)

    assert "same_taste" in [row["username"] for row in data["people"]]


async def test_one_shared_interest_is_enough(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    rows = (await client.get("/v1/interests", headers=mine)).json()["data"]["items"]
    await set_interests(client, mine, [rows[0]["slug"], rows[1]["slug"]])

    theirs = await auth_headers(client, account("one_match"))
    await set_interests(client, theirs, [rows[1]["slug"], rows[2]["slug"]])

    data = await suggestions(client, mine)

    assert "one_match" in [row["username"] for row in data["people"]]


async def test_sharing_nothing_is_not_a_suggestion(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    rows = (await client.get("/v1/interests", headers=mine)).json()["data"]["items"]
    await set_interests(client, mine, [rows[0]["slug"]])

    theirs = await auth_headers(client, account("no_match"))
    await set_interests(client, theirs, [rows[5]["slug"]])

    data = await suggestions(client, mine)

    assert "no_match" not in [row["username"] for row in data["people"]]


async def test_the_reason_says_what_you_have_in_common(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    picked = await some_interests(client, mine, 1)
    await set_interests(client, mine, [picked[0]["slug"]])

    theirs = await auth_headers(client, account("shared_reason"))
    await set_interests(client, theirs, [picked[0]["slug"]])

    data = await suggestions(client, mine)
    row = next(r for r in data["people"] if r["username"] == "shared_reason")

    assert "interest" in row["reason"].lower() or "same" in row["reason"].lower()
