from app.adapters.ai_gemini import ModerationUnavailable as AIUnavailable
from app.ports.ai import ALLOWED, StoryDraft, StoryReview


class NoAIAdapter:
    @property
    def is_available(self) -> bool:
        return False

    async def review_story(
        self,
        *,
        title: str | None,
        body: str,
        community: str | None,
        rooms: list[str] | None = None,
    ) -> StoryReview:
        return ALLOWED

    async def polish(self, *, text: str, instruction: str) -> str:
        raise AIUnavailable

    async def draft_story(self, *, subject: str, brief: str) -> StoryDraft:
        raise AIUnavailable
