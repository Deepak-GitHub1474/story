from dataclasses import dataclass, field
from typing import Protocol


@dataclass(frozen=True)
class StoryReview:
    is_allowed: bool = True
    rule: str | None = None
    reason: str | None = None
    exposes: list[str] = field(default_factory=list)
    suggested_community: str | None = None
    needs_care: bool = False

    @property
    def is_exposing(self) -> bool:
        return bool(self.exposes)


ALLOWED = StoryReview()


class AIPort(Protocol):
    @property
    def is_available(self) -> bool: ...

    async def review_story(
        self, *, title: str | None, body: str, community: str | None
    ) -> StoryReview: ...

    async def polish(self, *, text: str, instruction: str) -> str: ...
