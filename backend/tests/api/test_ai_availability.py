from app.adapters.ai_gemini import GeminiAdapter
from app.adapters.ai_none import NoAIAdapter


async def test_without_a_provider_nothing_is_available():
    assert NoAIAdapter().is_available is False


async def test_a_provider_with_no_key_is_not_available():
    adapter = GeminiAdapter(api_key="", model="gemini-3.5-flash-lite", timeout=1.0)

    assert adapter.is_available is False, (
        "a configured provider with no key is not a working gate"
    )


async def test_a_provider_with_a_key_is_available():
    adapter = GeminiAdapter(api_key="k", model="gemini-3.5-flash-lite", timeout=1.0)

    assert adapter.is_available is True


async def test_the_gate_lets_everything_through_when_there_is_no_provider():
    review = await NoAIAdapter().review_story(title=None, body="anything at all", community=None)

    assert review.is_allowed is True, (
        "with no provider the gate is open, so AI_PROVIDER=none means unmoderated"
    )
