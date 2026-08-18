from app.ports.push import PushMessage, PushOutcome


class NoPushAdapter:
    @property
    def is_available(self) -> bool:
        return False

    async def send(self, messages: list[PushMessage]) -> PushOutcome:
        return PushOutcome()
