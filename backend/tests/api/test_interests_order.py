JOYFUL = {"joy", "love", "friendship", "wins", "beginnings", "everyday"}
HEAVY = {"grief", "sacrifice", "heartbreak", "loneliness"}


async def test_the_joyful_interests_come_first(client):
    items = (await client.get("/v1/interests")).json()["data"]["items"]

    assert {item["category_id"] for item in items[:8]} <= JOYFUL


async def test_the_heaviest_interests_come_last(client):
    items = (await client.get("/v1/interests")).json()["data"]["items"]

    assert {item["category_id"] for item in items[-4:]} <= HEAVY


async def test_each_category_arrives_in_one_run(client):
    items = (await client.get("/v1/interests")).json()["data"]["items"]

    seen: list[str] = []
    for item in items:
        if not seen or seen[-1] != item["category_id"]:
            seen.append(item["category_id"])

    assert len(seen) == len(set(seen)), f"a category was split across the list: {seen}"


async def test_joy_is_the_very_first_category(client):
    items = (await client.get("/v1/interests")).json()["data"]["items"]

    assert items[0]["category_id"] == "joy"
