import json

import httpx
import pytest

from app.adapters.ai_gemini import GeminiAdapter, ModerationUnavailable


def reply(text: str) -> httpx.Response:
    return httpx.Response(
        200, json={"candidates": [{"content": {"parts": [{"text": json.dumps({"text": text})}]}}]}
    )


def adapter(handler):
    return GeminiAdapter(
        api_key="a-key",
        model="m",
        timeout=2.0,
        transport=httpx.MockTransport(handler),
    )


async def test_it_gives_back_a_rewritten_version():
    polished = await adapter(lambda request: reply("The tidy version.")).polish(
        text="the messy version", instruction="fix my spelling"
    )

    assert polished == "The tidy version."


async def test_it_sends_both_the_words_and_what_was_asked_for():
    seen = {}

    def handler(request):
        seen["body"] = request.content.decode()
        return reply("done")

    await adapter(handler).polish(text="my words", instruction="make it shorter")

    assert "my words" in seen["body"]
    assert "make it shorter" in seen["body"]


async def test_a_dead_provider_says_so_rather_than_returning_nothing():
    def handler(request):
        raise httpx.ConnectError("no route")

    with pytest.raises(ModerationUnavailable):
        await adapter(handler).polish(text="my words", instruction="tidy it")


async def test_an_empty_answer_is_refused():
    def handler(request):
        return httpx.Response(
            200, json={"candidates": [{"content": {"parts": [{"text": '{"text": "  "}'}]}}]}
        )

    with pytest.raises(ModerationUnavailable):
        await adapter(handler).polish(text="my words", instruction="tidy it")
