import json

import httpx
import pytest

from app.adapters.ai_gemini import DRAFT_INSTRUCTION, GeminiAdapter


@pytest.fixture(autouse=True)
def clean_state():
    yield


def capture() -> tuple[list[dict], httpx.MockTransport]:
    seen: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": json.dumps(
                                        {"title": "A Quiet Tuesday", "body": "It began."}
                                    )
                                }
                            ]
                        }
                    }
                ]
            },
        )

    return seen, httpx.MockTransport(handler)


async def test_the_draft_is_allowed_room_to_be_long():
    seen, transport = capture()
    adapter = GeminiAdapter(
        api_key="a-key", model="gemini-2.5-flash", timeout=2.0, transport=transport
    )

    await adapter.draft_story(subject="Leaving home", brief="I left at nineteen.")

    config = seen[0]["generationConfig"]
    assert config["maxOutputTokens"] >= 4096, (
        "a story capped at the default budget cannot reach the length asked for"
    )


def test_a_thin_brief_is_no_longer_told_to_stay_short():
    assert "keep the story short rather than padding it" not in DRAFT_INSTRUCTION, (
        "this sentence is why a request for 100 lines came back brief-sized"
    )


def test_a_length_request_outranks_the_house_style():
    lowered = DRAFT_INSTRUCTION.lower()
    assert "length" in lowered
    assert "outranks" in lowered, "the model needs to know which rule wins"


def test_the_writer_facts_are_still_theirs_alone():
    lowered = DRAFT_INSTRUCTION.lower()
    for forbidden in ("names", "places", "dates", "ages"):
        assert forbidden in lowered, (
            f"the draft may grow longer but must still not invent {forbidden}"
        )


async def test_the_subject_and_brief_are_what_gets_sent():
    seen, transport = capture()
    adapter = GeminiAdapter(
        api_key="a-key", model="gemini-2.5-flash", timeout=2.0, transport=transport
    )

    await adapter.draft_story(subject="Leaving home", brief="write 100 lines")

    sent = seen[0]["contents"][0]["parts"][0]["text"]
    assert "write 100 lines" in sent, "the length request must reach the model"
