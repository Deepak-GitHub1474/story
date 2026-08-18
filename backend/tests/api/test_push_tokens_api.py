from app.api.endpoints.notifications.constants import PUSH_TOKENS

TOKEN = "f" * 160
OTHER = "e" * 160


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def auth_headers(client, name):
    tokens = (await client.post("/v1/auth/signup", json=account(name))).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def register(client, headers, token=TOKEN, platform="android"):
    return await client.post(
        "/v1/notifications/push-tokens",
        json={"token": token, "platform": platform},
        headers=headers,
    )


async def test_a_phone_can_register_for_push(client, app_instance, unique_username):
    headers = await auth_headers(client, unique_username)

    response = await register(client, headers)

    assert response.status_code == 201, response.text
    assert response.json()["data"]["registered"] is True

    row = await app_instance.state.mongo_db[PUSH_TOKENS].find_one({"token": TOKEN})
    assert row is not None, "the token must actually be stored"
    assert row["_id"].startswith("psh_"), f"unexpected id: {row['_id']}"
    assert row["platform"] == "android"


async def test_registering_twice_keeps_one_row(client, app_instance, unique_username):
    headers = await auth_headers(client, unique_username)

    await register(client, headers)
    await register(client, headers)

    count = await app_instance.state.mongo_db[PUSH_TOKENS].count_documents({"token": TOKEN})
    assert count == 1, "re-registering the same phone must not stack rows"


async def test_a_shared_phone_only_reaches_whoever_signed_in_last(
    client, app_instance, unique_username
):
    first = await auth_headers(client, unique_username)
    await register(client, first)
    owner_before = (
        await app_instance.state.mongo_db[PUSH_TOKENS].find_one({"token": TOKEN})
    )["user_id"]

    second = await auth_headers(client, f"{unique_username}b")
    await register(client, second)

    rows = await app_instance.state.mongo_db[PUSH_TOKENS].find({"token": TOKEN}).to_list(10)
    assert len(rows) == 1, "one token, one row, or both accounts get each other's pushes"
    assert rows[0]["user_id"] != owner_before, "the token must follow the current signer-in"


async def test_turning_push_off_erases_the_token(client, app_instance, unique_username):
    headers = await auth_headers(client, unique_username)
    await register(client, headers)

    response = await client.request(
        "DELETE",
        "/v1/notifications/push-tokens",
        json={"token": TOKEN},
        headers=headers,
    )

    assert response.status_code == 200, response.text
    count = await app_instance.state.mongo_db[PUSH_TOKENS].count_documents({"token": TOKEN})
    assert count == 0, "an opted-out phone must leave nothing behind"


async def test_nobody_can_unregister_someone_elses_phone(
    client, app_instance, unique_username
):
    mine = await auth_headers(client, unique_username)
    await register(client, mine)

    theirs = await auth_headers(client, f"{unique_username}c")
    await client.request(
        "DELETE",
        "/v1/notifications/push-tokens",
        json={"token": TOKEN},
        headers=theirs,
    )

    count = await app_instance.state.mongo_db[PUSH_TOKENS].count_documents({"token": TOKEN})
    assert count == 1, "deleting by token alone would let anyone silence any phone"


async def test_registering_needs_a_session(client):
    response = await register(client, {})

    assert response.status_code == 401


async def test_a_junk_platform_is_refused(client, unique_username):
    headers = await auth_headers(client, unique_username)

    response = await register(client, headers, token=OTHER, platform="symbian")

    assert response.status_code == 422
