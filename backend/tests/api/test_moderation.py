import pytest

from app.adapters.ai_gemini import ModerationUnavailable
from app.ports.ai import StoryReview


class FakeAI:
    def __init__(self, review=None, error=None):
        self.review = review or StoryReview()
        self.error = error
        self.seen = []

    @property
    def is_available(self) -> bool:
        return True

    async def review_story(self, *, title, body, community):
        self.seen.append({"title": title, "body": body, "community": community})
        if self.error:
            raise self.error
        return self.review


@pytest.fixture
def use_ai(app_instance):
    from app.core import deps

    def install(fake):
        app_instance.dependency_overrides[deps.get_ai] = lambda: fake
        return fake

    yield install
    app_instance.dependency_overrides.clear()


async def auth_headers(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def draft(client, headers, body="Something worth saying."):
    return (
        await client.post("/v1/stories", json={"body": body}, headers=headers)
    ).json()["data"]["story"]["story_id"]


async def test_a_clean_story_publishes(client, signup_payload, use_ai):
    use_ai(FakeAI())
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["data"]["story"]["visibility"] == "public"


async def test_a_rule_breaking_story_is_refused_with_its_rule(client, signup_payload, use_ai):
    use_ai(
        FakeAI(
            StoryReview(
                is_allowed=False,
                rule="doxxing",
                reason="It prints someone's home address.",
            )
        )
    )
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 422
    payload = response.json()
    assert payload["data"]["code"] == "MODERATION_BLOCKED"
    assert payload["data"]["rule"] == "doxxing"
    assert "address" in payload["message"]


async def test_a_refused_story_is_kept_as_a_draft(client, signup_payload, use_ai):
    use_ai(FakeAI(StoryReview(is_allowed=False, rule="doxxing", reason="No.")))
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )
    story = (await client.get(f"/v1/stories/{story_id}", headers=headers)).json()["data"]["story"]

    assert story["visibility"] == "draft"


async def test_a_story_that_would_expose_its_author_warns_first(client, signup_payload, use_ai):
    use_ai(FakeAI(StoryReview(exposes=["employer", "phone number"])))
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 422
    payload = response.json()
    assert payload["data"]["code"] == "EXPOSURE_ACK_REQUIRED"
    assert payload["data"]["exposes"] == ["employer", "phone number"]


async def test_the_author_can_publish_anyway(client, signup_payload, use_ai):
    use_ai(FakeAI(StoryReview(exposes=["employer"])))
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish",
        json={"visibility": "public", "exposure_ack": True},
        headers=headers,
    )

    assert response.status_code == 200


async def test_a_room_suggestion_never_stops_publishing(client, signup_payload, use_ai):
    use_ai(FakeAI(StoryReview(suggested_community="job-hunting")))
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["data"]["suggested_community"] == "job-hunting"


async def test_someone_in_distress_is_never_blocked(client, signup_payload, use_ai):
    use_ai(FakeAI(StoryReview(needs_care=True)))
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["data"]["needs_care"] is True


async def test_a_dead_gate_refuses_to_publish_and_keeps_the_story(
    client, signup_payload, use_ai
):
    use_ai(FakeAI(error=ModerationUnavailable()))
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 503
    assert response.json()["data"]["code"] == "MODERATION_UNAVAILABLE"

    story = (await client.get(f"/v1/stories/{story_id}", headers=headers)).json()["data"]["story"]
    assert story["visibility"] == "draft"


async def test_a_private_story_is_never_sent_to_the_gate(client, signup_payload, use_ai):
    fake = use_ai(FakeAI())
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "private"}, headers=headers
    )

    assert response.status_code == 200
    assert fake.seen == []


async def test_a_draft_is_never_sent_to_the_gate(client, signup_payload, use_ai):
    fake = use_ai(FakeAI())
    headers = await auth_headers(client, signup_payload)
    await draft(client, headers)

    assert fake.seen == []


async def test_the_gate_sees_the_story_and_its_room(client, signup_payload, use_ai):
    fake = use_ai(FakeAI())
    headers = await auth_headers(client, signup_payload)
    story_id = (
        await client.post(
            "/v1/stories",
            json={"title": "A title", "body": "The words."},
            headers=headers,
        )
    ).json()["data"]["story"]["story_id"]

    await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert fake.seen[0]["title"] == "A title"
    assert fake.seen[0]["body"] == "The words."


async def test_with_no_provider_configured_publishing_still_works(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story_id = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story_id}/publish", json={"visibility": "public"}, headers=headers
    )

    assert response.status_code == 200
