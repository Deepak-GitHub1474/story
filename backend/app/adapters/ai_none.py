from app.ports.ai import ALLOWED, StoryReview


class NoAIAdapter:
    @property
    def is_available(self) -> bool:
        return False

    async def review_story(
        self, *, title: str | None, body: str, community: str | None
    ) -> StoryReview:
        return ALLOWED
