from app.config import get_settings
from app.core.crypto import encrypt_email

USER_KEYS = "user_keys"


async def signed_in(client, name="pwchanger"):
    payload = {"username": name, "password": "another-long-password", "tnc_accepted": True}
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def with_verified_email(client, app_instance, headers):
    settings = get_settings()
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    await app_instance.state.mongo_db[USER_KEYS].update_one(
        {"_id": me["user_id"]},
        {
            "$set": {
                "email_verified": True,
                "email_ciphertext": encrypt_email(
                    "someone@example.com", key=settings.EMAIL_ENCRYPTION_KEY
                ),
            }
        },
        upsert=True,
    )
    return me["user_id"]


async def test_the_wrong_current_password_is_still_refused(client):
    headers = await signed_in(client, "pwchanger_a")

    response = await client.post(
        "/v1/auth/password/change",
        json={
            "current_password": "not-the-right-one",
            "new_password": "a-brand-new-password",
        },
        headers=headers,
    )

    assert response.status_code == 401


async def test_a_verified_address_must_confirm_by_code(client, app_instance):
    headers = await signed_in(client, "pwchanger_b")
    await with_verified_email(client, app_instance, headers)

    response = await client.post(
        "/v1/auth/password/change",
        json={
            "current_password": "another-long-password",
            "new_password": "a-brand-new-password",
        },
        headers=headers,
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "OTP_REQUIRED"


async def test_an_account_with_no_address_changes_on_the_password_alone(client):
    headers = await signed_in(client, "pwchanger_c")

    response = await client.post(
        "/v1/auth/password/change",
        json={
            "current_password": "another-long-password",
            "new_password": "a-brand-new-password",
        },
        headers=headers,
    )

    assert response.status_code == 200


async def test_a_wrong_code_does_not_change_the_password(client, app_instance):
    headers = await signed_in(client, "pwchanger_d")
    await with_verified_email(client, app_instance, headers)

    response = await client.post(
        "/v1/auth/password/change",
        json={
            "current_password": "another-long-password",
            "new_password": "a-brand-new-password",
            "otp": "000000",
        },
        headers=headers,
    )

    assert response.status_code in (400, 401, 403)

    still = await client.post(
        "/v1/auth/signin",
        json={"username": "pwchanger_d", "password": "another-long-password"},
    )
    assert still.status_code == 200, "the old password must still work"
