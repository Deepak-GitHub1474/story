import pytest

from app.config import get_settings


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def with_email(client, payload, address="deepak@example.com"):
    headers = await auth_headers(client, payload)
    await client.post("/v1/users/me/email", json={"email": address}, headers=headers)
    return headers


def sent_otp():
    from app.adapters.mail_console import outbox

    return outbox[-1]["otp"]


async def clear_cooldown(app_instance, headers, client):
    from app.db import keys

    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    await app_instance.state.redis.delete(keys.otp_cooldown(me["user_id"]))


def test_the_lifetime_is_ten_minutes():
    assert get_settings().OTP_TTL_SECONDS == 600


def test_the_lockout_is_a_quarter_of_an_hour():
    assert get_settings().OTP_LOCKOUT_SECONDS == 900


def test_five_wrong_tries_locks():
    assert get_settings().OTP_FAIL_THRESHOLD == 5


async def test_a_correct_code_verifies(client, signup_payload):
    headers = await with_email(client, signup_payload)

    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": sent_otp()}, headers=headers
    )

    assert response.status_code == 200


async def test_a_code_cannot_be_used_twice(client, signup_payload):
    headers = await with_email(client, signup_payload)
    otp = sent_otp()

    first = await client.post(
        "/v1/users/me/email/verify", json={"otp": otp}, headers=headers
    )
    second = await client.post(
        "/v1/users/me/email/verify", json={"otp": otp}, headers=headers
    )

    assert first.status_code == 200
    assert second.status_code == 400
    assert second.json()["data"]["code"] == "OTP_INVALID"


async def test_the_record_is_gone_from_redis_once_used(
    client, signup_payload, app_instance
):
    from app.db import keys

    headers = await with_email(client, signup_payload)
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    await client.post(
        "/v1/users/me/email/verify", json={"otp": sent_otp()}, headers=headers
    )

    assert await app_instance.state.redis.exists(keys.email_otp(me["user_id"])) == 0


async def test_the_record_carries_a_ten_minute_ttl(client, signup_payload, app_instance):
    from app.db import keys

    headers = await with_email(client, signup_payload)
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    ttl = await app_instance.state.redis.ttl(keys.email_otp(me["user_id"]))

    assert 0 < ttl <= 600


async def test_five_wrong_codes_lock_the_account_out(client, signup_payload):
    headers = await with_email(client, signup_payload)

    for _ in range(4):
        wrong = await client.post(
            "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
        )
        assert wrong.json()["data"]["code"] == "OTP_INVALID"

    fifth = await client.post(
        "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
    )

    assert fifth.json()["data"]["code"] == "OTP_LOCKED"
    assert fifth.json()["data"]["retry_after_seconds"] == 900


async def test_the_right_code_is_refused_while_locked(client, signup_payload):
    headers = await with_email(client, signup_payload)
    otp = sent_otp()

    for _ in range(5):
        await client.post(
            "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
        )

    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": otp}, headers=headers
    )

    assert response.json()["data"]["code"] == "OTP_LOCKED"


async def test_a_locked_account_cannot_request_a_fresh_code(
    client, signup_payload, app_instance
):
    headers = await with_email(client, signup_payload)

    for _ in range(5):
        await client.post(
            "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
        )

    await clear_cooldown(app_instance, headers, client)
    response = await client.post(
        "/v1/users/me/email/resend", json={}, headers=headers
    )

    assert response.json()["data"]["code"] == "OTP_LOCKED"


async def test_the_lockout_expires_and_the_record_goes_with_it(
    client, signup_payload, app_instance
):
    from app.db import keys

    headers = await with_email(client, signup_payload)
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    for _ in range(5):
        await client.post(
            "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
        )

    ttl = await app_instance.state.redis.ttl(keys.email_otp(me["user_id"]))
    assert 0 < ttl <= 900


async def test_a_resend_does_not_reset_the_attempt_count(
    client, signup_payload, app_instance
):
    headers = await with_email(client, signup_payload)

    for _ in range(4):
        await client.post(
            "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
        )

    await clear_cooldown(app_instance, headers, client)
    await client.post(
        "/v1/users/me/email/resend", json={}, headers=headers
    )

    fifth = await client.post(
        "/v1/users/me/email/verify", json={"otp": "000000"}, headers=headers
    )

    assert fifth.json()["data"]["code"] == "OTP_LOCKED"


async def test_a_resend_inside_the_cooldown_is_refused(client, signup_payload):
    headers = await with_email(client, signup_payload)

    response = await client.post(
        "/v1/users/me/email/resend", json={}, headers=headers
    )

    assert response.json()["data"]["code"] == "OTP_COOLDOWN"


@pytest.mark.parametrize("otp", ["", "1", "abcdef", "0000000"])
async def test_a_malformed_code_is_refused(client, signup_payload, otp):
    headers = await with_email(client, signup_payload)

    response = await client.post(
        "/v1/users/me/email/verify", json={"otp": otp}, headers=headers
    )

    assert response.status_code in (400, 422)
