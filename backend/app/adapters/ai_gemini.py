import json
from typing import Any

import httpx

from app.logging import get_logger
from app.ports.ai import StoryReview

logger = get_logger("story.ai.gemini")

ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

RULES = """targeted-harassment: names or identifies a person and invites others to
attack, shame or contact them.
doxxing: publishes another living person's address, workplace, phone number,
account handle or face.
sexual-content-involving-minors: any sexual framing of someone under eighteen.
credible-threat: a specific stated intent to hurt a named person or place.
illegal-goods: offers to sell or source drugs, weapons or stolen credentials."""

INSTRUCTION = f"""You are the pre-publication gate for STORY, a place where people
write anonymously about things they cannot say elsewhere: grief, abuse they
survived, addiction, illness, joy, love, failure.

Almost everything belongs here. Heavy, dark, explicit and hopeless writing about
the author's own life is exactly what this place is for and must be allowed. You
are not a taste filter and not a safety blanket. Block only what breaks one of
these five rules:

{RULES}

Return JSON with these fields:
- allowed: false only when a rule above is broken, otherwise true.
- rule: the rule name when blocking, otherwise null.
- reason: one plain sentence a person would understand, when blocking.
- exposes: list of things in the story that could identify its own author to a
  reader who knows them, such as "employer", "phone number", "street name",
  "school", "rare job title". Empty when nothing does. This never blocks.
- suggested_community: a better community slug when the story clearly belongs in
  a different room from the one chosen, otherwise null. This never blocks.
- needs_care: true when the author sounds at risk of harming themselves. This
  never blocks and never changes what is published."""

SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "allowed": {"type": "boolean"},
        "rule": {"type": "string", "nullable": True},
        "reason": {"type": "string", "nullable": True},
        "exposes": {"type": "array", "items": {"type": "string"}},
        "suggested_community": {"type": "string", "nullable": True},
        "needs_care": {"type": "boolean"},
    },
    "required": ["allowed"],
}


class ModerationUnavailable(Exception):
    pass


class GeminiAdapter:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        timeout: float,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._timeout = timeout
        self._transport = transport

    @property
    def is_available(self) -> bool:
        return bool(self._api_key)

    def _payload(self, *, title: str | None, body: str, community: str | None) -> dict:
        story = json.dumps(
            {"title": title, "body": body, "community": community},
            ensure_ascii=False,
        )
        return {
            "system_instruction": {"parts": [{"text": INSTRUCTION}]},
            "contents": [{"role": "user", "parts": [{"text": story}]}],
            "generationConfig": {
                "temperature": 0,
                "responseMimeType": "application/json",
                "responseSchema": SCHEMA,
            },
        }

    async def review_story(
        self, *, title: str | None, body: str, community: str | None
    ) -> StoryReview:
        try:
            async with httpx.AsyncClient(
                timeout=self._timeout, transport=self._transport
            ) as client:
                response = await client.post(
                    ENDPOINT.format(model=self._model),
                    headers={"x-goog-api-key": self._api_key},
                    json=self._payload(title=title, body=body, community=community),
                )
        except httpx.HTTPError as error:
            logger.error("ai_unreachable", error=type(error).__name__)
            raise ModerationUnavailable from error

        if response.status_code != 200:
            logger.error("ai_refused", status=response.status_code)
            raise ModerationUnavailable

        try:
            candidates = response.json()["candidates"]
            text = candidates[0]["content"]["parts"][0]["text"]
            verdict = json.loads(text)
        except (KeyError, IndexError, ValueError, TypeError) as error:
            logger.error("ai_unreadable", error=type(error).__name__)
            raise ModerationUnavailable from error

        if not isinstance(verdict, dict) or "allowed" not in verdict:
            logger.error("ai_unreadable", error="missing_allowed")
            raise ModerationUnavailable

        exposes = verdict.get("exposes") or []
        return StoryReview(
            is_allowed=bool(verdict["allowed"]),
            rule=verdict.get("rule"),
            reason=verdict.get("reason"),
            exposes=[str(item) for item in exposes if str(item).strip()],
            suggested_community=verdict.get("suggested_community"),
            needs_care=bool(verdict.get("needs_care", False)),
        )
