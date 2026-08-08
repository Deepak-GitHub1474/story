async def signed(client, name):
    payload = {"username": name, "password": "another-long-password", "tnc_accepted": True}
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def follow(client, headers, username):
    return await client.post(f"/v1/connections/{username}", headers=headers)


async def people(client, headers, **params):
    query = "&".join(f"{k}={v}" for k, v in params.items())
    response = await client.get(f"/v1/chat/people?{query}", headers=headers)
    assert response.status_code == 200
    return response.json()["data"]


async def test_the_people_you_follow_are_offered(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    await signed(client, "chat_pal_one")
    await follow(client, mine, "chat_pal_one")

    data = await people(client, mine)

    assert "chat_pal_one" in [row["username"] for row in data["items"]]


async def test_someone_you_do_not_follow_is_not_offered(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    await signed(client, "chat_stranger")

    data = await people(client, mine)

    assert "chat_stranger" not in [row["username"] for row in data["items"]]


async def test_you_are_never_offered_yourself(client, signup_payload):
    mine = await signed(client, signup_payload["username"])

    data = await people(client, mine)

    assert signup_payload["username"] not in [row["username"] for row in data["items"]]


async def test_the_ones_who_follow_you_back_come_first(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    one_way = await signed(client, "chat_oneway")
    mutual = await signed(client, "chat_mutual")

    await follow(client, mine, "chat_oneway")
    await follow(client, mine, "chat_mutual")
    await follow(client, mutual, signup_payload["username"])
    assert one_way

    data = await people(client, mine)
    names = [row["username"] for row in data["items"]]

    assert names.index("chat_mutual") < names.index("chat_oneway")


async def test_a_mutual_follow_says_the_chat_opens_straight_away(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    mutual = await signed(client, "chat_mutual2")
    await follow(client, mine, "chat_mutual2")
    await follow(client, mutual, signup_payload["username"])

    data = await people(client, mine)
    row = next(r for r in data["items"] if r["username"] == "chat_mutual2")

    assert row["opens_straight_away"] is True


async def test_someone_you_already_have_a_chat_with_is_not_offered_again(
    client, signup_payload
):
    mine = await signed(client, signup_payload["username"])
    other = await signed(client, "chat_already")
    await follow(client, mine, "chat_already")
    await follow(client, other, signup_payload["username"])

    for headers in (mine, other):
        await client.post("/v1/chat/identity", json={"public_key": "a" * 44}, headers=headers)
    await client.post(
        "/v1/chat/conversations",
        json={
            "username": "chat_already",
            "wrapped_cek_for_me": "x" * 40,
            "wrapped_cek_for_them": "y" * 40,
            "sender_public_key": "a" * 44,
        },
        headers=mine,
    )

    data = await people(client, mine)

    assert "chat_already" not in [row["username"] for row in data["items"]]


async def test_only_twenty_come_back_at_once(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    for index in range(22):
        name = f"chat_many{index}"
        await signed(client, name)
        await follow(client, mine, name)

    data = await people(client, mine, limit=20)

    assert len(data["items"]) == 20
    assert data["has_more"] is True
    assert data["next_cursor"]


async def test_the_rest_arrive_on_the_next_page(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    for index in range(22):
        name = f"chat_page{index}"
        await signed(client, name)
        await follow(client, mine, name)

    first = await people(client, mine, limit=20)
    second = await people(client, mine, limit=20, cursor=first["next_cursor"])

    names = {row["username"] for row in first["items"]}
    assert len(second["items"]) == 2
    assert not names & {row["username"] for row in second["items"]}


async def test_it_needs_an_account(client):
    assert (await client.get("/v1/chat/people")).status_code == 401


async def test_conversations_come_back_newest_first_and_in_pages(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    await client.post("/v1/chat/identity", json={"public_key": "a" * 44}, headers=mine)

    made = []
    for index in range(4):
        name = f"chat_order{index}"
        other = await signed(client, name)
        await client.post("/v1/chat/identity", json={"public_key": "b" * 44}, headers=other)
        await follow(client, mine, name)
        await follow(client, other, signup_payload["username"])
        started = await client.post(
            "/v1/chat/conversations",
            json={
                "username": name,
                "wrapped_cek_for_me": "x" * 40,
                "wrapped_cek_for_them": "y" * 40,
                "sender_public_key": "a" * 44,
            },
            headers=mine,
        )
        made.append(started.json()["data"]["conversation"]["conversation_id"])

    first = (
        await client.get("/v1/chat/conversations?limit=2", headers=mine)
    ).json()["data"]

    assert len(first["items"]) == 2
    assert first["has_more"] is True

    second = (
        await client.get(
            f"/v1/chat/conversations?limit=2&cursor={first['next_cursor']}", headers=mine
        )
    ).json()["data"]

    assert len(second["items"]) == 2
    seen = {row["conversation_id"] for row in first["items"]}
    assert not seen & {row["conversation_id"] for row in second["items"]}


async def test_a_new_message_lifts_that_chat_to_the_top(client, signup_payload):
    mine = await signed(client, signup_payload["username"])
    await client.post("/v1/chat/identity", json={"public_key": "a" * 44}, headers=mine)

    ids = []
    for index in range(2):
        name = f"chat_lift{index}"
        other = await signed(client, name)
        await client.post("/v1/chat/identity", json={"public_key": "b" * 44}, headers=other)
        await follow(client, mine, name)
        await follow(client, other, signup_payload["username"])
        started = await client.post(
            "/v1/chat/conversations",
            json={
                "username": name,
                "wrapped_cek_for_me": "x" * 40,
                "wrapped_cek_for_them": "y" * 40,
                "sender_public_key": "a" * 44,
            },
            headers=mine,
        )
        ids.append(started.json()["data"]["conversation"]["conversation_id"])

    oldest = ids[0]
    await client.post(
        f"/v1/chat/conversations/{oldest}/messages",
        json={"ciphertext": "z" * 40},
        headers=mine,
    )

    listed = (await client.get("/v1/chat/conversations", headers=mine)).json()["data"]

    assert listed["items"][0]["conversation_id"] == oldest


async def _mutual_pair(client, signup_payload, name):
    mine = await signed(client, signup_payload["username"])
    other = await signed(client, name)
    await follow(client, mine, name)
    await follow(client, other, signup_payload["username"])
    for headers in (mine, other):
        await client.post("/v1/chat/identity", json={"public_key": "a" * 44}, headers=headers)
    return mine, other


async def _start(client, mine, name):
    response = await client.post(
        "/v1/chat/conversations",
        json={
            "username": name,
            "wrapped_cek_for_me": "x" * 40,
            "wrapped_cek_for_them": "y" * 40,
            "sender_public_key": "a" * 44,
        },
        headers=mine,
    )
    return response.json()["data"]["conversation"]["conversation_id"]


async def test_someone_whose_chat_you_deleted_is_offered_again(client, signup_payload):
    mine, _ = await _mutual_pair(client, signup_payload, "chat_deleted")
    conversation = await _start(client, mine, "chat_deleted")
    await client.delete(f"/v1/chat/conversations/{conversation}", headers=mine)

    data = await people(client, mine)

    assert "chat_deleted" in [row["username"] for row in data["items"]]


async def test_starting_again_brings_the_deleted_chat_back(client, signup_payload):
    mine, _ = await _mutual_pair(client, signup_payload, "chat_return")
    conversation = await _start(client, mine, "chat_return")
    await client.delete(f"/v1/chat/conversations/{conversation}", headers=mine)

    assert (await client.get("/v1/chat/conversations", headers=mine)).json()["data"][
        "items"
    ] == []

    again = await _start(client, mine, "chat_return")
    listed = (await client.get("/v1/chat/conversations", headers=mine)).json()["data"]

    assert again == conversation
    assert [row["conversation_id"] for row in listed["items"]] == [conversation]
