import pytest


class FakeMail:
    def __init__(self):
        self.alerts = []
        self.codes = []

    async def send_otp(self, *, email, otp, purpose):
        self.codes.append((email, otp, purpose))

    async def send_security_alert(self, *, email, subject, body):
        self.alerts.append({"email": email, "subject": subject, "body": body})


@pytest.fixture
def mail(app_instance):
    from app.core import deps

    fake = FakeMail()
    app_instance.dependency_overrides[deps.get_mail] = lambda: fake
    yield fake
    app_instance.dependency_overrides.clear()


def phone(model="Pixel 8", os_version="Android 14"):
    return {
        "platform": "android",
        "os_version": os_version,
        "app_version": "1.0.0",
        "device_model": model,
    }


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def signin(client, payload, device):
    return await client.post(
        "/v1/auth/signin",
        json={
            "username": payload["username"],
            "password": payload["password"],
            "device": device,
        },
    )


async def with_verified_email(client, payload, mail):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    headers = {"authorization": f"Bearer {tokens['access_token']}"}
    await client.post(
        "/v1/users/me/email", json={"email": "someone@example.com"}, headers=headers
    )
    otp = mail.codes[-1][1]
    await client.post("/v1/users/me/email/verify", json={"otp": otp}, headers=headers)
    mail.alerts.clear()
    return headers


async def test_a_new_phone_warns_the_account_owner(client, signup_payload, mail):
    await with_verified_email(client, signup_payload, mail)

    await signin(client, signup_payload, phone(model="Galaxy S24"))

    assert len(mail.alerts) == 1
    assert "Galaxy S24" in mail.alerts[0]["body"]


async def test_the_same_phone_signing_in_again_says_nothing(client, signup_payload, mail):
    await with_verified_email(client, signup_payload, mail)

    await signin(client, signup_payload, phone())
    mail.alerts.clear()
    await signin(client, signup_payload, phone())

    assert mail.alerts == []


async def test_an_account_with_no_email_is_not_told(client, signup_payload, mail):
    await signup(client, signup_payload)
    mail.alerts.clear()

    await signin(client, signup_payload, phone(model="Galaxy S24"))

    assert mail.alerts == []


async def test_an_unverified_address_is_not_written_to(client, signup_payload, mail):
    tokens = (await signup(client, signup_payload)).json()["data"]["tokens"]
    headers = {"authorization": f"Bearer {tokens['access_token']}"}
    await client.post(
        "/v1/users/me/email", json={"email": "someone@example.com"}, headers=headers
    )
    mail.alerts.clear()

    await signin(client, signup_payload, phone(model="Galaxy S24"))

    assert mail.alerts == []


async def test_the_warning_never_carries_the_password_or_a_token(
    client, signup_payload, mail
):
    await with_verified_email(client, signup_payload, mail)

    await signin(client, signup_payload, phone(model="Galaxy S24"))

    body = mail.alerts[0]["body"]
    assert signup_payload["password"] not in body
    assert "Bearer" not in body


async def test_a_failed_sign_in_never_warns(client, signup_payload, mail):
    await with_verified_email(client, signup_payload, mail)

    await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": "not-the-password",
            "device": phone(model="Galaxy S24"),
        },
    )

    assert mail.alerts == []
