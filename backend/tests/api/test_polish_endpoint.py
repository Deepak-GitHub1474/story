import pytest


class FakeAI:
    def __init__(self, text="Polished.", error=None):
        self.text = text
        self.error = error
        self.seen = []

    @property
    def is_available(self):
        return True

    async def review_story(self, **_):
        from app.ports.ai import ALLOWED

        return ALLOWED

    async def polish(self, *, text, instruction):
        self.seen.append({"text": text, "instruction": instruction})
        if self.error:
            raise self.error
        return self.text


@pytest.fixture
def use_ai(app_instance):
    from app.core import deps

    def install(fake):
        app_instance.dependency_overrides[deps.get_ai] = lambda: fake
        return fake

    yield install
    app_instance.dependency_overrides.clear()


async def headers_for(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def test_a_writer_can_ask_for_a_tidier_version(client, signup_payload, use_ai):
    fake = use_ai(FakeAI("The tidy version."))
    headers = await headers_for(client, signup_payload)

    response = await client.post(
        "/v1/ai/polish",
        json={"text": "the messy version", "instruction": "fix my spelling"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["text"] == "The tidy version."
    assert fake.seen[0]["instruction"] == "fix my spelling"


async def test_it_needs_an_account(client):
    response = await client.post(
        "/v1/ai/polish", json={"text": "words", "instruction": "tidy"}
    )

    assert response.status_code == 401


async def test_empty_writing_is_refused_before_it_costs_anything(
    client, signup_payload, use_ai
):
    fake = use_ai(FakeAI())
    headers = await headers_for(client, signup_payload)

    response = await client.post(
        "/v1/ai/polish", json={"text": "   ", "instruction": "tidy"}, headers=headers
    )

    assert response.status_code == 422
    assert fake.seen == []


async def test_a_dead_provider_says_so(client, signup_payload, use_ai):
    from app.adapters.ai_gemini import ModerationUnavailable

    use_ai(FakeAI(error=ModerationUnavailable()))
    headers = await headers_for(client, signup_payload)

    response = await client.post(
        "/v1/ai/polish",
        json={"text": "the messy version", "instruction": "tidy"},
        headers=headers,
    )

    assert response.status_code == 503


async def test_with_no_provider_configured_it_says_so_rather_than_failing_oddly(
    client, signup_payload
):
    headers = await headers_for(client, signup_payload)

    response = await client.post(
        "/v1/ai/polish",
        json={"text": "the messy version", "instruction": "tidy"},
        headers=headers,
    )

    assert response.status_code == 503
