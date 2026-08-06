import pytest

from app.adapters.mail_smtp import SmtpMailAdapter


class FakeSmtp:
    def __init__(self):
        self.sent = []
        self.started_tls = False
        self.logged_in_as = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        return False

    async def starttls(self):
        self.started_tls = True

    async def login(self, username, password):
        self.logged_in_as = (username, password)

    async def send(self, message):
        self.sent.append(message)


@pytest.fixture
def transport():
    return FakeSmtp()


def adapter(transport, **overrides):
    return SmtpMailAdapter(
        host="smtp.example.com",
        port=587,
        username="postmaster@story.test",
        password="a-secret",
        from_address="Story <hello@story.test>",
        use_tls=True,
        transport=lambda **_: transport,
        **overrides,
    )


async def test_an_otp_reaches_the_address(transport):
    await adapter(transport).send_otp(
        email="deepak@example.com", otp="123456", purpose="password_reset"
    )

    assert len(transport.sent) == 1
    assert transport.sent[0]["To"] == "deepak@example.com"


async def test_the_code_is_in_the_body(transport):
    await adapter(transport).send_otp(
        email="deepak@example.com", otp="123456", purpose="password_reset"
    )

    assert "123456" in transport.sent[0].get_content()


async def test_the_subject_says_what_it_is_for(transport):
    await adapter(transport).send_otp(
        email="deepak@example.com", otp="123456", purpose="password_reset"
    )

    assert "Story" in transport.sent[0]["Subject"]


async def test_it_starts_tls_before_logging_in(transport):
    await adapter(transport).send_otp(
        email="deepak@example.com", otp="123456", purpose="verify_email"
    )

    assert transport.started_tls is True
    assert transport.logged_in_as == ("postmaster@story.test", "a-secret")


async def test_the_from_address_is_ours(transport):
    await adapter(transport).send_otp(
        email="deepak@example.com", otp="1", purpose="verify_email"
    )

    assert transport.sent[0]["From"] == "Story <hello@story.test>"


async def test_a_security_alert_carries_its_subject_and_body(transport):
    await adapter(transport).send_security_alert(
        email="deepak@example.com",
        subject="A new sign in",
        body="Someone signed in from a new device.",
    )

    message = transport.sent[0]
    assert message["Subject"] == "A new sign in"
    assert "new device" in message.get_content()


async def test_the_password_never_appears_in_the_message(transport):
    await adapter(transport).send_otp(
        email="deepak@example.com", otp="123456", purpose="password_reset"
    )

    assert "a-secret" not in str(transport.sent[0])


async def test_a_send_failure_is_swallowed_rather_than_breaking_the_request(transport):
    class Broken(FakeSmtp):
        async def send(self, message):
            raise OSError("connection refused")

    broken = Broken()
    await adapter(broken).send_otp(
        email="deepak@example.com", otp="1", purpose="verify_email"
    )

    assert broken.sent == []
