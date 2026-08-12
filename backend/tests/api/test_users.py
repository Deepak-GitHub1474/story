async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def test_interests_catalogue_is_seeded(client):
    response = await client.get("/v1/interests")
    assert response.status_code == 200
    items = response.json()["data"]["items"]
    assert len(items) >= 10
    assert {"slug", "name", "category_id"} <= set(items[0])


async def test_interests_are_grouped_by_category(client):
    items = (await client.get("/v1/interests")).json()["data"]["items"]
    categories = {item["category_id"] for item in items}
    assert len(categories) >= 5


async def test_profile_update_changes_display_name(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch(
        "/v1/users/me", json={"display_name": "Quiet Fox"}, headers=headers
    )
    assert response.status_code == 200
    assert response.json()["data"]["user"]["display_name"] == "Quiet Fox"


async def test_profile_update_changes_bio(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch("/v1/users/me", json={"bio": "Still here."}, headers=headers)
    assert response.json()["data"]["user"]["bio"] == "Still here."


async def test_profile_update_rejects_a_bio_with_a_link(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch(
        "/v1/users/me", json={"bio": "find me at https://example.com"}, headers=headers
    )
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "BIO_LINK_NOT_ALLOWED"


async def test_profile_update_sets_interests_and_marks_onboarding(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch(
        "/v1/users/me", json={"interests": ["grief", "loneliness"]}, headers=headers
    )
    user = response.json()["data"]["user"]
    assert user["interests"] == ["grief", "loneliness"]
    assert user["onboarding"]["interests_done"] is True


async def test_profile_update_rejects_an_unknown_interest(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch(
        "/v1/users/me", json={"interests": ["not-a-real-interest"]}, headers=headers
    )
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "INTEREST_UNKNOWN"


async def test_profile_update_changes_prefs(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch(
        "/v1/users/me", json={"prefs": {"theme": "paper"}}, headers=headers
    )
    assert response.json()["data"]["user"]["prefs"]["theme"] == "paper"


async def test_profile_update_keeps_unlisted_prefs(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.patch("/v1/users/me", json={"prefs": {"theme": "paper"}}, headers=headers)
    response = await client.patch(
        "/v1/users/me", json={"prefs": {"reading_size": "readingLg"}}, headers=headers
    )
    prefs = response.json()["data"]["user"]["prefs"]
    assert prefs["theme"] == "paper"
    assert prefs["reading_size"] == "readingLg"


async def test_profile_update_cannot_escalate_role(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch("/v1/users/me", json={"role": "admin"}, headers=headers)
    assert response.status_code == 422


async def test_profile_update_cannot_unblock_self(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch("/v1/users/me", json={"blocked": False}, headers=headers)
    assert response.status_code == 422


async def test_avatar_regenerate_changes_the_seed(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    before = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    after = (await client.post("/v1/users/me/avatar/regenerate", headers=headers)).json()["data"][
        "user"
    ]
    assert after["avatar_seed"] != before["avatar_seed"]


async def test_public_profile_is_visible_to_another_account(client, signup_payload):
    await signup(client, signup_payload)
    other = {
        "username": "onlooker",
        "password": "another-long-password",
        "tnc_accepted": True,
    }
    headers = await auth_headers(client, other)
    response = await client.get(f"/v1/users/{signup_payload['username']}", headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["user"]["username"] == signup_payload["username"]


async def test_public_profile_hides_private_fields(client, signup_payload):
    await signup(client, signup_payload)
    other = {
        "username": "onlooker2",
        "password": "another-long-password",
        "tnc_accepted": True,
    }
    headers = await auth_headers(client, other)
    user = (await client.get(f"/v1/users/{signup_payload['username']}", headers=headers)).json()[
        "data"
    ]["user"]
    assert "referral_code" not in user
    assert "login_info" not in user
    assert "prefs" not in user


async def test_public_profile_of_an_unknown_user_is_404(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/users/nobody_at_all", headers=headers)
    assert response.status_code == 404


async def test_sessions_lists_the_current_device(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/auth/sessions", headers=headers)
    assert response.status_code == 200
    items = response.json()["data"]["items"]
    assert len(items) == 1
    assert items[0]["is_current"] is True


async def test_sessions_lists_each_signin_separately(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    items = (await client.get("/v1/auth/sessions", headers=headers)).json()["data"]["items"]
    assert len(items) == 2


async def test_revoking_a_session_kills_its_refresh_token(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    other = (
        await client.post(
            "/v1/auth/signin",
            json={
                "username": signup_payload["username"],
                "password": signup_payload["password"],
            },
        )
    ).json()["data"]

    items = (await client.get("/v1/auth/sessions", headers=headers)).json()["data"]["items"]
    target = next(item for item in items if not item["is_current"])

    response = await client.delete(f"/v1/auth/sessions/{target['family_id']}", headers=headers)
    assert response.status_code == 200

    refresh = await client.post(
        "/v1/auth/refresh", json={"refresh_token": other["tokens"]["refresh_token"]}
    )
    assert refresh.status_code == 401


async def test_password_change_preserves_the_session(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/auth/password/change",
        json={
            "current_password": signup_payload["password"],
            "new_password": "a-brand-new-long-password",
        },
        headers=headers,
    )
    assert response.status_code == 200
    assert (await client.get("/v1/auth/me", headers=headers)).status_code == 200


async def test_password_change_requires_the_current_password(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/auth/password/change",
        json={"current_password": "wrong-one-entirely", "new_password": "a-new-long-password"},
        headers=headers,
    )
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "INVALID_CREDENTIALS"


async def test_password_change_enforces_strength(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/auth/password/change",
        json={"current_password": signup_payload["password"], "new_password": "short"},
        headers=headers,
    )
    assert response.status_code == 422


async def test_the_new_password_works_and_the_old_one_does_not(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/auth/password/change",
        json={
            "current_password": signup_payload["password"],
            "new_password": "a-brand-new-long-password",
        },
        headers=headers,
    )

    old = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    new = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": "a-brand-new-long-password",
        },
    )
    assert old.status_code == 401
    assert new.status_code == 200


async def test_the_two_extra_themes_are_allowed(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    for name in ("blush", "maroon", "system", "paper", "midnight"):
        response = await client.patch(
            "/v1/users/me", json={"prefs": {"theme": name}}, headers=headers
        )
        assert response.status_code == 200, name
        assert response.json()["data"]["user"]["prefs"]["theme"] == name


async def test_a_theme_we_do_not_ship_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.patch(
        "/v1/users/me", json={"prefs": {"theme": "neon"}}, headers=headers
    )

    assert response.status_code == 422


async def test_a_new_account_starts_on_system(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    user = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    assert user["prefs"]["theme"] == "system"
