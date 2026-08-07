async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def publish(client, headers, body, community=None):
    if community:
        await client.post(f"/v1/communities/{community}/join", headers=headers)
    story = (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()[
        "data"
    ]["story"]
    payload = {"visibility": "public"}
    if community:
        payload["community_slug"] = community
    await client.post(
        f"/v1/stories/{story['story_id']}/publish", json=payload, headers=headers
    )
    return story["story_id"]


def bodies(items):
    return [item["excerpt"] for item in items]


async def test_a_reader_with_interests_sees_them_before_anything_else(client):
    writer = await auth_headers(client, account("tone_writer"))
    await publish(client, writer, "A heavy one.", community="quiet-grief")
    await publish(client, writer, "A bright one.", community="good-day")
    await publish(client, writer, "A travel one.", community="out-there")

    reader = await auth_headers(client, account("tone_reader"))
    await client.patch("/v1/users/me", json={"interests": ["travel"]}, headers=reader)

    feed = (await client.get("/v1/stories/feed", headers=reader)).json()["data"]["items"]

    assert bodies(feed)[0].startswith("A travel one")


async def test_without_interests_the_bright_ones_come_first(client):
    writer = await auth_headers(client, account("tone_writer2"))
    await publish(client, writer, "A heavy one.", community="quiet-grief")
    await publish(client, writer, "A bright one.", community="good-day")

    reader = await auth_headers(client, account("tone_reader2"))
    feed = (await client.get("/v1/stories/feed", headers=reader)).json()["data"]["items"]

    assert bodies(feed)[0].startswith("A bright one")


async def test_the_heavy_ones_are_still_reachable_further_down(client):
    writer = await auth_headers(client, account("tone_writer3"))
    await publish(client, writer, "A heavy one.", community="quiet-grief")
    await publish(client, writer, "A bright one.", community="good-day")

    reader = await auth_headers(client, account("tone_reader3"))
    feed = (await client.get("/v1/stories/feed", headers=reader)).json()["data"]["items"]

    assert any(body.startswith("A heavy one") for body in bodies(feed))


async def test_nothing_appears_twice_across_the_phases(client):
    writer = await auth_headers(client, account("tone_writer4"))
    for index in range(6):
        await publish(client, writer, f"Bright {index}.", community="good-day")
        await publish(client, writer, f"Heavy {index}.", community="quiet-grief")

    reader = await auth_headers(client, account("tone_reader4"))
    await client.patch("/v1/users/me", json={"interests": ["good-days"]}, headers=reader)

    seen: list[str] = []
    cursor = None
    for _ in range(8):
        query = f"?limit=5&cursor={cursor}" if cursor else "?limit=5"
        page = (await client.get(f"/v1/stories/feed{query}", headers=reader)).json()["data"]
        seen.extend(item["story_id"] for item in page["items"])
        cursor = page["next_cursor"]
        if not page["has_more"]:
            break

    assert len(seen) == len(set(seen))


async def test_a_story_with_no_community_still_reaches_the_reader(client):
    writer = await auth_headers(client, account("tone_writer5"))
    await publish(client, writer, "No room at all.")

    reader = await auth_headers(client, account("tone_reader5"))

    seen: list[str] = []
    cursor = None
    for _ in range(6):
        query = f"?limit=10&cursor={cursor}" if cursor else "?limit=10"
        page = (await client.get(f"/v1/stories/feed{query}", headers=reader)).json()["data"]
        seen.extend(item["excerpt"] for item in page["items"])
        cursor = page["next_cursor"]
        if not page["has_more"]:
            break

    assert any(body.startswith("No room at all") for body in seen)
