import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def test_signup_creates_an_account(client, signup_payload):
    response = await signup(client, signup_payload)
    assert response.status_code == 201
    body = response.json()
    assert body["success"] is True
    assert body["data"]["user"]["username"] == signup_payload["username"]


async def test_signup_returns_a_token_pair(client, signup_payload):
    data = (await signup(client, signup_payload)).json()["data"]
    assert data["tokens"]["access_token"]
    assert data["tokens"]["refresh_token"]
    assert data["tokens"]["token_type"] == "bearer"


async def test_signup_never_returns_the_password_hash(client, signup_payload):
    body = (await signup(client, signup_payload)).text
    assert "password_hash" not in body
    assert "argon2" not in body


async def test_signup_issues_a_referral_code(client, signup_payload):
    user = (await signup(client, signup_payload)).json()["data"]["user"]
    assert len(user["referral_code"]) == 6
    assert user["referral_code"].isupper()


async def test_signup_defaults_are_correct(client, signup_payload):
    user = (await signup(client, signup_payload)).json()["data"]["user"]
    assert user["role"] == "user"
    assert user["status"] == "active"
    assert user["blocked"] is False
    assert user["referred_by"] is None
    assert user["login_info"] is None


async def test_signup_rejects_a_duplicate_username(client, signup_payload):
    await signup(client, signup_payload)
    response = await signup(client, signup_payload)
    assert response.status_code == 409
    assert response.json()["data"]["code"] == "USERNAME_TAKEN"


async def test_signup_rejects_an_invalid_username(client, signup_payload):
    response = await signup(client, {**signup_payload, "username": "_ab"})
    assert response.status_code in (422,)
    assert response.json()["data"]["code"] in ("USERNAME_INVALID", "VALIDATION_FAILED")


async def test_signup_rejects_a_weak_password(client, signup_payload):
    response = await signup(client, {**signup_payload, "password": "password123"})
    assert response.status_code == 422
    assert response.json()["data"]["code"] in ("PASSWORD_TOO_WEAK", "VALIDATION_FAILED")


async def test_signup_rejects_unaccepted_terms(client, signup_payload):
    response = await signup(client, {**signup_payload, "tnc_accepted": False})
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "TNC_REQUIRED"


async def test_signup_rejects_an_unknown_referral_code(client, signup_payload):
    response = await signup(client, {**signup_payload, "referral_code": "ZZZZZZ"})
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "REFERRAL_CODE_INVALID"


async def test_signup_records_a_valid_referral_code(client, signup_payload):
    referrer = (await signup(client, signup_payload)).json()["data"]["user"]
    second = {
        "username": "referred_one",
        "password": "another-long-password",
        "tnc_accepted": True,
        "referral_code": referrer["referral_code"],
    }
    user = (await signup(client, second)).json()["data"]["user"]
    assert user["referred_by"] == referrer["referral_code"]


async def test_username_availability_is_true_before_signup(client, unique_username):
    response = await client.post("/v1/auth/username-available", json={"username": unique_username})
    assert response.json()["data"]["available"] is True


async def test_username_availability_is_false_after_signup(client, signup_payload):
    await signup(client, signup_payload)
    response = await client.post(
        "/v1/auth/username-available", json={"username": signup_payload["username"]}
    )
    assert response.json()["data"]["available"] is False


async def test_signin_succeeds_with_correct_credentials(client, signup_payload):
    await signup(client, signup_payload)
    response = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert response.status_code == 200
    assert response.json()["data"]["tokens"]["access_token"]


async def test_signin_records_login_info(client, signup_payload):
    await signup(client, signup_payload)
    response = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
            "device": {
                "platform": "android",
                "os_version": "Android 15",
                "app_version": "0.1.0",
                "device_model": "Pixel 8",
            },
        },
    )
    login_info = response.json()["data"]["user"]["login_info"]
    assert login_info["platform"] == "android"
    assert login_info["device_model"] == "Pixel 8"
    assert login_info["logged_in_at"].endswith("Z")


async def test_signin_stores_only_a_truncated_ip(client, signup_payload):
    await signup(client, signup_payload)
    response = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
        headers={"x-forwarded-for": "203.0.113.42"},
    )
    assert response.json()["data"]["user"]["login_info"]["ip_prefix"] == "203.0.113.0"


async def test_signin_rejects_a_wrong_password(client, signup_payload):
    await signup(client, signup_payload)
    response = await client.post(
        "/v1/auth/signin",
        json={"username": signup_payload["username"], "password": "wrong-password-here"},
    )
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "INVALID_CREDENTIALS"


async def test_signin_rejects_an_unknown_username_with_the_same_code(client):
    response = await client.post(
        "/v1/auth/signin",
        json={"username": "nobody_here", "password": "some-long-password"},
    )
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "INVALID_CREDENTIALS"


async def test_signin_rejects_a_blocked_account(client, signup_payload, app_instance):
    await signup(client, signup_payload)
    await app_instance.state.mongo_db["users"].update_one(
        {"username_lower": signup_payload["username"]}, {"$set": {"blocked": True}}
    )
    response = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert response.status_code == 403
    assert response.json()["data"]["code"] == "ACCOUNT_BLOCKED"


async def test_blocked_reason_is_never_returned(client, signup_payload, app_instance):
    await signup(client, signup_payload)
    await app_instance.state.mongo_db["users"].update_one(
        {"username_lower": signup_payload["username"]},
        {"$set": {"blocked": True, "blocked_reason": "internal note"}},
    )
    response = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert "internal note" not in response.text


async def test_me_returns_the_current_user(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    response = await client.get(
        "/v1/auth/me", headers={"authorization": f"Bearer {tokens['access_token']}"}
    )
    assert response.status_code == 200
    assert response.json()["data"]["user"]["username"] == signup_payload["username"]


async def test_me_requires_a_session(client):
    response = await client.get("/v1/auth/me")
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "SESSION_REQUIRED"


async def test_me_rejects_a_tampered_token(client):
    response = await client.get("/v1/auth/me", headers={"authorization": "Bearer not.a.real.token"})
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "TOKEN_INVALID"


async def test_refresh_rotates_the_refresh_token(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    response = await client.post(
        "/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert response.status_code == 200
    assert response.json()["data"]["tokens"]["refresh_token"] != tokens["refresh_token"]


async def test_refresh_issues_a_working_access_token(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    refreshed = (
        await client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).json()["data"]["tokens"]
    response = await client.get(
        "/v1/auth/me", headers={"authorization": f"Bearer {refreshed['access_token']}"}
    )
    assert response.status_code == 200


async def test_reusing_a_rotated_refresh_token_is_detected(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    await client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    response = await client.post(
        "/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "TOKEN_REUSED"


async def test_reuse_revokes_the_whole_family(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    rotated = (
        await client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    ).json()["data"]["tokens"]
    await client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    response = await client.post(
        "/v1/auth/refresh", json={"refresh_token": rotated["refresh_token"]}
    )
    assert response.status_code == 401


async def test_refresh_rejects_an_unknown_token(client):
    response = await client.post("/v1/auth/refresh", json={"refresh_token": "nope"})
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "TOKEN_INVALID"


async def test_signout_denylists_the_access_token(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    headers = {"authorization": f"Bearer {tokens['access_token']}"}
    assert (await client.post("/v1/auth/signout", headers=headers)).status_code == 200
    response = await client.get("/v1/auth/me", headers=headers)
    assert response.status_code == 401
    assert response.json()["data"]["code"] == "TOKEN_REVOKED"


async def test_signout_invalidates_the_refresh_token(client, signup_payload):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    await client.post(
        "/v1/auth/signout",
        headers={"authorization": f"Bearer {tokens['access_token']}"},
    )
    response = await client.post(
        "/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert response.status_code == 401


async def test_signout_all_revokes_every_session(client, signup_payload):
    await signup(client, signup_payload)
    creds = {
        "username": signup_payload["username"],
        "password": signup_payload["password"],
    }
    first = (await client.post("/v1/auth/signin", json=creds)).json()["data"]["tokens"]
    second = (await client.post("/v1/auth/signin", json=creds)).json()["data"]["tokens"]

    await client.post(
        "/v1/auth/signout-all",
        headers={"authorization": f"Bearer {second['access_token']}"},
    )
    response = await client.post("/v1/auth/refresh", json={"refresh_token": first["refresh_token"]})
    assert response.status_code == 401


@pytest.mark.parametrize("path", ["/v1/auth/signup", "/v1/auth/signin", "/v1/auth/refresh"])
async def test_validation_errors_use_the_standard_envelope(client, path):
    response = await client.post(path, json={})
    assert response.status_code == 422
    body = response.json()
    assert body["success"] is False
    assert body["data"]["code"] == "VALIDATION_FAILED"
    assert body["data"]["fields"]


async def test_extra_fields_are_rejected(client, signup_payload):
    response = await client.post("/v1/auth/signup", json={**signup_payload, "role": "super_admin"})
    assert response.status_code == 422


async def test_all_timestamps_end_with_z(client, signup_payload):
    user = (await signup(client, signup_payload)).json()["data"]["user"]
    assert user["created_at"].endswith("Z")
    assert user["created_at"].count(".") == 1
