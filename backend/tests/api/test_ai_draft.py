import contextlib

from app.core import deps
from app.ports.ai import ALLOWED, StoryDraft, StoryReview


async def signed_in(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


class FakeWriter:
    def __init__(self):
        self.asked = []

    @property
    def is_available(self) -> bool:
        return True

    async def review_story(self, **kwargs) -> StoryReview:
        return ALLOWED

    async def polish(self, *, text: str, instruction: str) -> str:
        return text

    async def draft_story(self, *, subject: str, brief: str) -> StoryDraft:
        self.asked.append((subject, brief))
        return StoryDraft(title="A Quiet Tuesday", body="It began the way most of it began.")


@contextlib.contextmanager
def writing(app_instance, fake):
    app_instance.dependency_overrides[deps.get_ai] = lambda: fake
    try:
        yield fake
    finally:
        app_instance.dependency_overrides.clear()


async def test_a_brief_becomes_a_titled_story(client, signup_payload, app_instance):
    headers = await signed_in(client, signup_payload)
    writer = FakeWriter()

    with writing(app_instance, writer):
        response = await client.post(
            "/v1/ai/draft",
            json={
                "subject": "leaving home",
                "brief": "I moved out at nineteen and never went back.",
            },
            headers=headers,
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["title"] == "A Quiet Tuesday"
    assert data["body"].startswith("It began")
    assert writer.asked == [
        ("leaving home", "I moved out at nineteen and never went back.")
    ]


async def test_an_empty_brief_is_refused(client, signup_payload, app_instance):
    headers = await signed_in(client, signup_payload)
    with writing(app_instance, FakeWriter()):
        response = await client.post(
            "/v1/ai/draft",
            json={"subject": "anything", "brief": "   "},
            headers=headers,
        )

    assert response.status_code == 422


async def test_drafting_needs_an_account(client):
    response = await client.post(
        "/v1/ai/draft", json={"subject": "x", "brief": "a real brief here"}
    )
    assert response.status_code == 401


async def test_the_gate_still_applies_to_what_the_model_wrote(
    client, signup_payload, app_instance
):
    headers = await signed_in(client, signup_payload)
    with writing(app_instance, FakeWriter()):
        drafted = (
            await client.post(
                "/v1/ai/draft",
                json={"subject": "leaving home", "brief": "I moved out at nineteen."},
                headers=headers,
            )
        ).json()["data"]

    created = await client.post(
        "/v1/stories",
        json={"title": drafted["title"], "body": drafted["body"]},
        headers=headers,
    )

    assert created.status_code == 201
    assert created.json()["data"]["story"]["visibility"] == "draft"
