import asyncio
import hashlib
import json
from collections import OrderedDict
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
- exposes: short list of the things in this story that could identify its own
  author to somebody who already knows them. Name the kind of detail, two or
  three words each, for example "employer", "phone number", "street name",
  "school", "rare job title", "full name", "car registration". Include a detail
  when it is rare enough to narrow the author down to a handful of people, even
  when it seems harmless on its own. Empty list when nothing does. This never
  blocks.
- suggested_community: a better community slug when the story clearly belongs in
  a different room from the one chosen, otherwise null. This never blocks.
- needs_care: true when the author sounds at risk of ending their life or
  hurting themselves. Read what they mean, not the words they use. Statements
  like "everyone would be better off without me", "I do not want to wake up",
  "I am done", or planning language all count. Ordinary grief, exhaustion and
  despair do not. This never blocks and never changes what is published."""

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


RETRYABLE = frozenset({408, 500, 502, 503, 504})
CACHE_LIMIT = 256


class ModerationUnavailable(Exception):
    pass


class GeminiAdapter:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        timeout: float,
        retries: int = 3,
        backoff: float = 0.4,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._timeout = timeout
        self._retries = max(1, retries)
        self._backoff = backoff
        self._transport = transport
        self._seen: OrderedDict[str, StoryReview] = OrderedDict()

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

    async def _ask(self, payload: dict) -> httpx.Response:
        last_error: Exception | None = None

        for attempt in range(self._retries):
            if attempt:
                await asyncio.sleep(self._backoff * attempt)

            try:
                async with httpx.AsyncClient(
                    timeout=self._timeout, transport=self._transport
                ) as client:
                    response = await client.post(
                        ENDPOINT.format(model=self._model),
                        headers={"x-goog-api-key": self._api_key},
                        json=payload,
                    )
            except httpx.HTTPError as error:
                logger.warning("ai_unreachable", error=type(error).__name__)
                last_error = error
                continue

            if response.status_code == 200:
                return response

            logger.warning("ai_refused", status=response.status_code)
            if response.status_code not in RETRYABLE:
                raise ModerationUnavailable
            last_error = None

        raise ModerationUnavailable from last_error

    def _fingerprint(self, title: str | None, body: str, community: str | None) -> str:
        digest = hashlib.sha256()
        digest.update(f"{title}\x00{body}\x00{community}".encode())
        return digest.hexdigest()

    def _remember(self, fingerprint: str, review: StoryReview) -> None:
        self._seen[fingerprint] = review
        while len(self._seen) > CACHE_LIMIT:
            self._seen.popitem(last=False)

    async def review_story(
        self, *, title: str | None, body: str, community: str | None
    ) -> StoryReview:
        fingerprint = self._fingerprint(title, body, community)
        remembered = self._seen.get(fingerprint)
        if remembered is not None:
            return remembered

        response = await self._ask(
            self._payload(title=title, body=body, community=community)
        )

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
        review = StoryReview(
            is_allowed=bool(verdict["allowed"]),
            rule=verdict.get("rule"),
            reason=verdict.get("reason"),
            exposes=[str(item) for item in exposes if str(item).strip()],
            suggested_community=verdict.get("suggested_community"),
            needs_care=bool(verdict.get("needs_care", False)),
        )
        self._remember(fingerprint, review)
        return review
