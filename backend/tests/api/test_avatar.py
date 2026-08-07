async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def test_a_chosen_avatar_seed_sticks(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.patch(
        "/v1/users/me", json={"avatar_seed": "a1b2c3d4e5f60718"}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["data"]["user"]["avatar_seed"] == "a1b2c3d4e5f60718"


async def test_the_chosen_seed_survives_a_reload(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.patch(
        "/v1/users/me", json={"avatar_seed": "0011223344556677"}, headers=headers
    )

    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    assert me["avatar_seed"] == "0011223344556677"


async def test_a_seed_that_is_not_hex_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.patch(
        "/v1/users/me", json={"avatar_seed": "not-a-real-seed!"}, headers=headers
    )

    assert response.status_code == 422


async def test_a_seed_of_the_wrong_length_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    for seed in ("abc", "a" * 64):
        response = await client.patch(
            "/v1/users/me", json={"avatar_seed": seed}, headers=headers
        )
        assert response.status_code == 422, seed


async def test_uppercase_hex_is_folded(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.patch(
        "/v1/users/me", json={"avatar_seed": "AABBCCDDEEFF0011"}, headers=headers
    )

    assert response.json()["data"]["user"]["avatar_seed"] == "aabbccddeeff0011"


async def test_regenerate_still_works_and_changes_it(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.patch(
        "/v1/users/me", json={"avatar_seed": "0011223344556677"}, headers=headers
    )

    response = await client.post("/v1/users/me/avatar/regenerate", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["user"]["avatar_seed"] != "0011223344556677"


async def test_a_chosen_avatar_shows_to_other_people(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.patch(
        "/v1/users/me", json={"avatar_seed": "beefbeefbeefbeef"}, headers=headers
    )

    other = await auth_headers(
        client,
        {"username": "avatar_watcher", "password": "another-long-password", "tnc_accepted": True},
    )
    profile = (
        await client.get(f"/v1/users/{signup_payload['username']}", headers=other)
    ).json()["data"]["user"]

    assert profile["avatar_seed"] == "beefbeefbeefbeef"
