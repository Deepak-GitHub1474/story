import json

import httpx
import pytest

from app.adapters.ai_gemini import GeminiAdapter, ModerationUnavailable


def reply(payload: dict) -> httpx.Response:
    return httpx.Response(
        200,
        json={"candidates": [{"content": {"parts": [{"text": json.dumps(payload)}]}}]},
    )


def adapter(handler, **overrides):
    transport = httpx.MockTransport(handler)
    return GeminiAdapter(
        api_key="a-key",
        model="gemini-2.5-flash",
        timeout=2.0,
        transport=transport,
        **overrides,
    )


async def test_a_clean_story_is_allowed():
    review = await adapter(lambda request: reply({"allowed": True})).review_story(
        title="A good day", body="Something went right today.", community="good-day"
    )

    assert review.is_allowed
    assert review.rule is None
    assert review.exposes == []


async def test_a_broken_rule_blocks_and_says_which():
    review = await adapter(
        lambda request: reply(
            {
                "allowed": False,
                "rule": "targeted-harassment",
                "reason": "Names a person and calls for pile-on.",
            }
        )
    ).review_story(title=None, body="whatever", community=None)

    assert not review.is_allowed
    assert review.rule == "targeted-harassment"
    assert "pile-on" in review.reason


async def test_self_exposing_details_are_named_but_never_block():
    review = await adapter(
        lambda request: reply({"allowed": True, "exposes": ["phone number", "employer"]})
    ).review_story(title=None, body="call me on 555 at Acme", community=None)

    assert review.is_allowed
    assert review.is_exposing
    assert review.exposes == ["phone number", "employer"]


async def test_a_story_in_the_wrong_room_is_redirected_not_blocked():
    review = await adapter(
        lambda request: reply({"allowed": True, "suggested_community": "job-hunting"})
    ).review_story(title=None, body="I need work", community="grief")

    assert review.is_allowed
    assert review.suggested_community == "job-hunting"


async def test_distress_is_flagged_and_never_blocks():
    review = await adapter(
        lambda request: reply({"allowed": True, "needs_care": True})
    ).review_story(title=None, body="I cannot go on", community=None)

    assert review.is_allowed
    assert review.needs_care


async def test_the_key_is_sent_as_a_header_not_in_the_url():
    seen = {}

    def handler(request):
        seen["url"] = str(request.url)
        seen["header"] = request.headers.get("x-goog-api-key")
        return reply({"allowed": True})

    await adapter(handler).review_story(title=None, body="hello", community=None)

    assert seen["header"] == "a-key"
    assert "a-key" not in seen["url"]


async def test_the_story_text_is_what_gets_reviewed():
    seen = {}

    def handler(request):
        seen["body"] = request.content.decode()
        return reply({"allowed": True})

    await adapter(handler).review_story(
        title="My title", body="My body", community="good-day"
    )

    assert "My body" in seen["body"]
    assert "My title" in seen["body"]
    assert "good-day" in seen["body"]


async def test_a_dead_provider_is_not_a_silent_pass():
    def handler(request):
        raise httpx.ConnectError("no route")

    with pytest.raises(ModerationUnavailable):
        await adapter(handler).review_story(title=None, body="hello", community=None)


async def test_a_refusal_from_the_model_is_not_a_silent_pass():
    with pytest.raises(ModerationUnavailable):
        await adapter(lambda request: httpx.Response(429)).review_story(
            title=None, body="hello", community=None
        )


async def test_nonsense_back_from_the_model_is_not_a_silent_pass():
    def handler(request):
        return httpx.Response(
            200, json={"candidates": [{"content": {"parts": [{"text": "not json"}]}}]}
        )

    with pytest.raises(ModerationUnavailable):
        await adapter(handler).review_story(title=None, body="hello", community=None)


async def test_an_adapter_with_a_key_reports_itself_available():
    assert adapter(lambda request: reply({"allowed": True})).is_available
