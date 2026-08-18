from dataclasses import dataclass, field
from typing import Protocol


@dataclass(frozen=True)
class PushMessage:
    token: str
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class PushOutcome:
    delivered: tuple[str, ...] = ()
    stale: tuple[str, ...] = ()
    retry: tuple[str, ...] = ()

    @property
    def sent(self) -> int:
        return len(self.delivered)


class PushPort(Protocol):
    @property
    def is_available(self) -> bool: ...

    async def send(self, messages: list[PushMessage]) -> PushOutcome: ...
