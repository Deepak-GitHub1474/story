def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def signed_in(client, name):
    body = (await client.post("/v1/auth/signup", json=account(name))).json()["data"]
    return (
        {"authorization": f"Bearer {body['tokens']['access_token']}"},
        body["user"]["user_id"],
    )


async def give_them_an_email(app_instance, user_id):
    await app_instance.state.mongo_db["user_keys"].update_one(
        {"_id": user_id},
        {"$set": {"email_masked": "d••••k@gmail.com", "email_verified": True}},
        upsert=True,
    )


async def test_updating_a_pref_returns_the_whole_user(
    client, app_instance, unique_username
):
    headers, user_id = await signed_in(client, unique_username)
    await give_them_an_email(app_instance, user_id)

    response = await client.patch(
        "/v1/users/me", json={"prefs": {"notify_push": True}}, headers=headers
    )

    user = response.json()["data"]["user"]
    assert user["prefs"]["notify_push"] is True
    assert user["email_masked"] == "d••••k@gmail.com", (
        "the client adopts this object wholesale, so a missing email erases "
        "the one the reader actually has"
    )
    assert user["email_verified"] is True


async def test_a_new_avatar_returns_the_whole_user(
    client, app_instance, unique_username
):
    headers, user_id = await signed_in(client, unique_username)
    await give_them_an_email(app_instance, user_id)

    response = await client.post("/v1/users/me/avatar/regenerate", headers=headers)

    user = response.json()["data"]["user"]
    assert user["email_masked"] == "d••••k@gmail.com"


async def test_the_patch_payload_matches_what_me_returns(
    client, app_instance, unique_username
):
    headers, user_id = await signed_in(client, unique_username)
    await give_them_an_email(app_instance, user_id)

    patched = (
        await client.patch(
            "/v1/users/me", json={"prefs": {"notify_in_app": False}}, headers=headers
        )
    ).json()["data"]["user"]
    fetched = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    assert patched.keys() == fetched.keys()
    assert patched == fetched, (
        "adopting the patch response must leave the client in the same state "
        "a refetch would have produced"
    )
