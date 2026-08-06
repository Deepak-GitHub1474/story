async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def test_browsing_communities_leads_with_the_joyful_rooms(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    items = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"]
    categories = [item["category_id"] for item in items[:6]]

    assert set(categories) <= {"joy", "love", "friendship", "wins", "beginnings", "everyday"}


async def test_the_heaviest_rooms_come_last(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    items = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"]
    tail = [item["category_id"] for item in items[-4:]]

    assert set(tail) <= {"grief", "sacrifice", "heartbreak", "loneliness"}


async def test_searching_communities_also_leads_with_the_joyful_ones(
    client, signup_payload
):
    headers = await auth_headers(client, signup_payload)

    results = (await client.get("/v1/search?q=ad", headers=headers)).json()["data"]
    names = [item["name"] for item in results["communities"]]

    assert names, "the probe query should still match something"
    heavy = {"Bad Manager", "Bad Brain Days", "The Road Not Taken"}
    first_heavy = next((i for i, name in enumerate(names) if name in heavy), len(names))
    first_light = next((i for i, name in enumerate(names) if name not in heavy), len(names))

    assert first_light < first_heavy


async def test_rooms_dropped_from_the_seed_stop_being_offered(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    items = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"]
    slugs = {item["slug"] for item in items}

    assert "second-first-date" not in slugs
    assert "unseen" in slugs


async def test_a_retired_room_keeps_its_stories_rather_than_vanishing(
    client, signup_payload, app_instance
):
    await app_instance.state.mongo_db["communities"].update_one(
        {"_id": "unseen"}, {"$set": {"status": "retired"}}
    )
    headers = await auth_headers(client, signup_payload)

    response = await client.get("/v1/communities/unseen", headers=headers)

    assert response.status_code == 200
