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


def parts_of(message):
    return {part.get_content_type(): part.get_content() for part in message.iter_parts()}


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

    assert "123456" in parts_of(transport.sent[0])["text/plain"]


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
    assert "new device" in parts_of(message)["text/plain"]


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


async def test_a_code_email_carries_a_readable_and_a_plain_version(transport):
    await adapter(transport).send_otp(
        email="someone@story.test", otp="483920", purpose="verify_email"
    )

    message = transport.sent[0]
    assert message.get_content_type() == "multipart/alternative"
    parts = {part.get_content_type(): part.get_content() for part in message.iter_parts()}
    assert "483920" in parts["text/plain"]
    assert "483920" in parts["text/html"]


async def test_the_html_version_is_a_whole_document(transport):
    await adapter(transport).send_otp(
        email="someone@story.test", otp="483920", purpose="password_reset"
    )

    parts = {
        part.get_content_type(): part.get_content()
        for part in transport.sent[0].iter_parts()
    }
    html = parts["text/html"]
    assert html.strip().startswith("<!doctype html>")
    assert "</html>" in html


async def test_a_code_email_says_which_account_it_is_for(transport):
    await adapter(transport).send_otp(
        email="someone@story.test", otp="483920", purpose="verify_email"
    )

    message = transport.sent[0]
    assert message["To"] == "someone@story.test"
    assert message["From"] == "Story <hello@story.test>"
    assert "confirm" in message["Subject"].lower()


async def test_the_email_never_names_the_person_it_is_sent_to(transport):
    await adapter(transport).send_otp(
        email="rakesh.gupta.1994@story.test", otp="483920", purpose="verify_email"
    )

    body = "".join(part.get_content() for part in transport.sent[0].iter_parts())
    assert "rakesh" not in body.lower()


async def test_a_security_alert_is_also_readable(transport):
    await adapter(transport).send_security_alert(
        email="someone@story.test",
        subject="Story — a new sign in",
        body="Somebody signed in from a new device.",
    )

    parts = {
        part.get_content_type(): part.get_content()
        for part in transport.sent[0].iter_parts()
    }
    assert "new device" in parts["text/plain"]
    assert "new device" in parts["text/html"]
