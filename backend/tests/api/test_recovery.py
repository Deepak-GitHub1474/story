import pytest

from app.adapters.mail_console import outbox


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


@pytest.fixture(autouse=True)
def clear_outbox():
    outbox.clear()
    yield
    outbox.clear()


def last_otp():
    return outbox[-1]["otp"]


async def add_email(client, headers, address="deepak@example.com"):
    return await client.post("/v1/users/me/email", json={"email": address}, headers=headers)


async def test_adding_an_email_sends_an_otp(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await add_email(client, headers)
    assert response.status_code == 200
    assert len(outbox) == 1


async def test_the_response_never_echoes_the_address(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await add_email(client, headers)
    assert "deepak@example.com" not in response.text


async def test_the_response_returns_a_masked_address(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    masked = (await add_email(client, headers)).json()["data"]["email_masked"]
    assert masked.startswith("d")
    assert "eepak" not in masked


async def test_the_plaintext_address_is_never_stored(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    keys = await app_instance.state.mongo_db["user_keys"].find_one({})
    assert "deepak@example.com" not in str(keys)


async def test_the_address_is_stored_as_a_blind_index_and_ciphertext(
    client, signup_payload, app_instance
):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    keys = await app_instance.state.mongo_db["user_keys"].find_one({})
    assert keys["email_index"]
    assert keys["email_ciphertext"]
    assert keys["email_verified"] is False


async def test_verifying_with_the_right_otp_succeeds(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers
    )
    assert response.status_code == 200
    assert response.json()["data"]["email_verified"] is True


async def test_verifying_with_a_wrong_otp_fails(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
    )
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "OTP_INVALID"


async def test_a_wrong_otp_reports_remaining_attempts(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
    )
    assert response.json()["data"]["attempts_remaining"] >= 1


async def test_too_many_wrong_otps_lock_the_code(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    for _ in range(6):
        response = await client.post(
            "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
        )

    assert response.status_code == 429
    assert response.json()["data"]["code"] == "OTP_LOCKED"


async def test_requesting_a_new_code_does_not_reset_the_attempt_counter(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    for _ in range(4):
        await client.post("/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers)

    await client.post("/v1/users/me/email/resend", json={}, headers=headers)
    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
    )
    assert response.json()["data"].get("attempts_remaining", 0) <= 1


async def test_resending_too_soon_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    response = await client.post("/v1/users/me/email/resend", json={}, headers=headers)
    assert response.status_code == 429
    assert response.json()["data"]["code"] == "OTP_COOLDOWN"


async def test_the_same_address_cannot_be_used_twice(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)

    other = await auth_headers(
        client,
        {"username": "otheruser", "password": "another-long-password", "tnc_accepted": True},
    )
    response = await add_email(client, other)
    assert response.status_code == 409
    assert response.json()["data"]["code"] == "EMAIL_IN_USE"


async def test_no_endpoint_returns_the_plaintext_email(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)

    me = await client.get("/v1/auth/me", headers=headers)
    assert "deepak@example.com" not in me.text
    assert me.json()["data"]["user"]["email_masked"].startswith("d")


async def test_removing_the_email_clears_it(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)

    response = await client.request(
        "DELETE",
        "/v1/users/me/email",
        json={"password": signup_payload["password"]},
        headers=headers,
    )
    assert response.status_code == 200
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    assert me["email_masked"] is None


async def test_removing_the_email_requires_the_password(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)

    response = await client.request(
        "DELETE",
        "/v1/users/me/email",
        json={"password": "not-the-right-one"},
        headers=headers,
    )
    assert response.status_code == 401


async def test_reset_request_always_responds_the_same(client, signup_payload):
    await signup(client, signup_payload)

    known = await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    unknown = await client.post(
        "/v1/auth/password-reset/request", json={"username": "nobody_here_at_all"}
    )

    assert known.status_code == unknown.status_code == 200
    assert known.json()["message"] == unknown.json()["message"]
    assert known.json()["data"] == unknown.json()["data"]


async def test_reset_without_an_email_sends_nothing(client, signup_payload):
    await signup(client, signup_payload)
    await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    assert outbox == []


async def test_a_full_reset_lets_the_new_password_sign_in(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)
    outbox.clear()

    await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    verify = await client.post(
        "/v1/auth/password-reset/verify",
        json={"username": signup_payload["username"], "otp": last_otp()},
    )
    reset_token = verify.json()["data"]["reset_token"]

    complete = await client.post(
        "/v1/auth/password-reset/complete",
        json={
            "reset_token": reset_token,
            "new_password": "a-brand-new-long-password",
            "acknowledged_vault_loss": True,
        },
    )
    assert complete.status_code == 200

    signin = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": "a-brand-new-long-password",
        },
    )
    assert signin.status_code == 200


async def test_reset_requires_acknowledging_the_loss(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)
    outbox.clear()

    await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    verify = await client.post(
        "/v1/auth/password-reset/verify",
        json={"username": signup_payload["username"], "otp": last_otp()},
    )

    response = await client.post(
        "/v1/auth/password-reset/complete",
        json={
            "reset_token": verify.json()["data"]["reset_token"],
            "new_password": "a-brand-new-long-password",
            "acknowledged_vault_loss": False,
        },
    )
    assert response.status_code == 422


async def test_a_reset_token_cannot_be_reused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)
    outbox.clear()

    await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    verify = await client.post(
        "/v1/auth/password-reset/verify",
        json={"username": signup_payload["username"], "otp": last_otp()},
    )
    token = verify.json()["data"]["reset_token"]
    body = {
        "reset_token": token,
        "new_password": "a-brand-new-long-password",
        "acknowledged_vault_loss": True,
    }

    await client.post("/v1/auth/password-reset/complete", json=body)
    second = await client.post("/v1/auth/password-reset/complete", json=body)
    assert second.status_code == 400


async def test_a_reset_signs_out_every_session(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await add_email(client, headers)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=headers)
    outbox.clear()

    await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    verify = await client.post(
        "/v1/auth/password-reset/verify",
        json={"username": signup_payload["username"], "otp": last_otp()},
    )
    await client.post(
        "/v1/auth/password-reset/complete",
        json={
            "reset_token": verify.json()["data"]["reset_token"],
            "new_password": "a-brand-new-long-password",
            "acknowledged_vault_loss": True,
        },
    )

    assert (await client.get("/v1/auth/me", headers=headers)).status_code == 401


async def test_a_pre_reset_token_stays_dead_after_the_owner_signs_in_again(client, signup_payload):
    stolen = await auth_headers(client, signup_payload)
    await add_email(client, stolen)
    await client.post("/v1/users/me/email/verify", json={"otp": last_otp()}, headers=stolen)
    outbox.clear()

    await client.post(
        "/v1/auth/password-reset/request", json={"username": signup_payload["username"]}
    )
    verify = await client.post(
        "/v1/auth/password-reset/verify",
        json={"username": signup_payload["username"], "otp": last_otp()},
    )
    await client.post(
        "/v1/auth/password-reset/complete",
        json={
            "reset_token": verify.json()["data"]["reset_token"],
            "new_password": "a-brand-new-long-password",
            "acknowledged_vault_loss": True,
        },
    )

    assert (await client.get("/v1/auth/me", headers=stolen)).status_code == 401

    signin = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": "a-brand-new-long-password",
        },
    )
    fresh = {"authorization": f"Bearer {signin.json()['data']['tokens']['access_token']}"}

    assert (await client.get("/v1/auth/me", headers=fresh)).status_code == 200
    assert (await client.get("/v1/auth/me", headers=stolen)).status_code == 401


async def test_a_pre_deactivation_token_stays_dead_after_reactivating(client, signup_payload):
    stolen = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/users/me/deactivate",
        json={"password": signup_payload["password"]},
        headers=stolen,
    )
    assert (await client.get("/v1/auth/me", headers=stolen)).status_code == 401

    signin = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    fresh = {"authorization": f"Bearer {signin.json()['data']['tokens']['access_token']}"}

    assert (await client.get("/v1/auth/me", headers=fresh)).status_code == 200
    assert (await client.get("/v1/auth/me", headers=stolen)).status_code == 401
