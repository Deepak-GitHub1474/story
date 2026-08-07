import asyncio
from collections.abc import Iterable
from typing import Any, Protocol

from app.logging import get_logger

logger = get_logger("story.realtime")


class Socket(Protocol):
    async def send_json(self, payload: dict[str, Any]) -> None: ...


class Hub:
    def __init__(self) -> None:
        self._sockets: dict[str, set[Socket]] = {}

    def attach(self, user_id: str, socket: Socket) -> None:
        self._sockets.setdefault(user_id, set()).add(socket)

    def detach(self, user_id: str, socket: Socket) -> None:
        sockets = self._sockets.get(user_id)
        if sockets is None:
            return

        sockets.discard(socket)
        if not sockets:
            self._sockets.pop(user_id, None)

    def is_online(self, user_id: str) -> bool:
        return bool(self._sockets.get(user_id))

    def count(self, user_id: str) -> int:
        return len(self._sockets.get(user_id, ()))

    async def deliver(self, user_id: str, payload: dict[str, Any]) -> None:
        sockets = list(self._sockets.get(user_id, ()))
        if not sockets:
            return

        results = await asyncio.gather(
            *(socket.send_json(payload) for socket in sockets),
            return_exceptions=True,
        )
        for socket, result in zip(sockets, results, strict=True):
            if isinstance(result, BaseException):
                self.detach(user_id, socket)

    async def broadcast(
        self,
        user_ids: Iterable[str],
        payload: dict[str, Any],
        *,
        skip: str | None = None,
    ) -> None:
        await asyncio.gather(
            *(
                self.deliver(user_id, payload)
                for user_id in user_ids
                if user_id != skip
            )
        )


hub = Hub()
