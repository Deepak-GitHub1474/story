import pytest

from app.adapters.mail_console import outbox
from app.config import get_settings


@pytest.fixture(autouse=True)
def clear_outbox():
    outbox.clear()
    yield
    outbox.clear()


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def recoverable(client, payload):
    headers = await auth_headers(client, payload)
    await client.post(
        "/v1/users/me/email",
        json={"email": f"{payload['username']}@example.com"},
        headers=headers,
    )
    await client.post(
        "/v1/users/me/email/verify", json={"otp": outbox[-1]["otp"]}, headers=headers
    )
    outbox.clear()
    return headers


async def ask_for_a_code(client, username):
    return await client.post("/v1/auth/password-reset/request", json={"username": username})


async def guess(client, username, otp="000000"):
    return await client.post(
        "/v1/auth/password-reset/verify", json={"username": username, "otp": otp}
    )


async def test_a_code_dies_after_five_wrong_guesses(client, signup_payload):
    await recoverable(client, signup_payload)
    await ask_for_a_code(client, signup_payload["username"])

    codes = [await guess(client, signup_payload["username"]) for _ in range(5)]

    assert [reply.json()["data"]["code"] for reply in codes[:4]] == ["OTP_INVALID"] * 4
    assert codes[4].json()["data"]["code"] == "OTP_LOCKED"


async def test_the_fourth_wrong_guess_says_one_is_left(client, signup_payload):
    await recoverable(client, signup_payload)
    await ask_for_a_code(client, signup_payload["username"])

    for _ in range(3):
        await guess(client, signup_payload["username"])
    fourth = await guess(client, signup_payload["username"])

    assert fourth.json()["data"]["attempts_remaining"] == 1


async def test_the_right_code_still_works_after_four_wrong_ones(client, signup_payload):
    await recoverable(client, signup_payload)
    await ask_for_a_code(client, signup_payload["username"])
    real = outbox[-1]["otp"]

    for _ in range(4):
        await guess(client, signup_payload["username"])
    good = await guess(client, signup_payload["username"], otp=real)

    assert good.status_code == 200
    assert good.json()["data"]["reset_token"]


async def test_the_lock_holds_for_a_quarter_of_an_hour(client, signup_payload):
    await recoverable(client, signup_payload)
    await ask_for_a_code(client, signup_payload["username"])

    for _ in range(5):
        locked = await guess(client, signup_payload["username"])

    assert locked.status_code == 429
    assert locked.json()["data"]["retry_after_seconds"] > 600


async def test_a_locked_account_cannot_be_handed_a_fresh_code(client, signup_payload):
    await recoverable(client, signup_payload)
    await ask_for_a_code(client, signup_payload["username"])
    for _ in range(5):
        await guess(client, signup_payload["username"])
    outbox.clear()

    again = await ask_for_a_code(client, signup_payload["username"])

    assert again.status_code == 200
    assert outbox == [], "a locked account must not be sent a way around the lock"


async def test_asking_twice_in_a_row_sends_only_one_code(client, signup_payload):
    await recoverable(client, signup_payload)

    await ask_for_a_code(client, signup_payload["username"])
    await ask_for_a_code(client, signup_payload["username"])

    assert len(outbox) == 1


async def test_asking_again_never_admits_the_account_exists(client, signup_payload):
    await recoverable(client, signup_payload)

    await ask_for_a_code(client, signup_payload["username"])
    second = await ask_for_a_code(client, signup_payload["username"])
    stranger = await ask_for_a_code(client, "nobody_here_at_all")

    assert second.status_code == stranger.status_code == 200
    assert second.json()["data"] == stranger.json()["data"]


async def test_a_locked_account_looks_like_any_other(client, signup_payload):
    await recoverable(client, signup_payload)
    await ask_for_a_code(client, signup_payload["username"])
    for _ in range(5):
        await guess(client, signup_payload["username"])

    locked = await ask_for_a_code(client, signup_payload["username"])
    stranger = await ask_for_a_code(client, "nobody_here_at_all")

    assert locked.json()["data"] == stranger.json()["data"]


async def test_the_app_is_told_how_long_a_code_lives(client, signup_payload):
    await recoverable(client, signup_payload)

    asked = await ask_for_a_code(client, signup_payload["username"])

    settings = get_settings()
    assert asked.json()["data"]["expires_in"] == settings.OTP_TTL_SECONDS
    assert asked.json()["data"]["resend_after"] == settings.OTP_RESEND_COOLDOWN_SECONDS


async def test_the_numbers_are_the_same_for_an_account_that_does_not_exist(client):
    stranger = await ask_for_a_code(client, "nobody_here_at_all")

    settings = get_settings()
    assert stranger.json()["data"]["expires_in"] == settings.OTP_TTL_SECONDS
    assert stranger.json()["data"]["resend_after"] == settings.OTP_RESEND_COOLDOWN_SECONDS


async def test_guessing_at_the_reset_code_is_rate_limited(client, signup_payload):
    settings = get_settings()
    settings.RATE_LIMIT_ENABLED = True
    try:
        replies = [await guess(client, signup_payload["username"]) for _ in range(12)]
    finally:
        settings.RATE_LIMIT_ENABLED = False

    assert replies[-1].status_code == 429
    assert replies[-1].json()["data"]["code"] == "RATE_LIMITED"
