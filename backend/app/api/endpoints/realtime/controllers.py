import secrets

from redis.asyncio import Redis

TICKET_PREFIX = "ST:WSTICKET:"
TICKET_TTL_SECONDS = 30
TICKET_BYTES = 24


def ticket_key(ticket: str) -> str:
    return f"{TICKET_PREFIX}{ticket}"


async def issue_ticket(user_id: str, *, redis: Redis) -> dict[str, object]:
    ticket = secrets.token_hex(TICKET_BYTES)
    await redis.set(ticket_key(ticket), user_id, ex=TICKET_TTL_SECONDS)
    return {"ticket": ticket, "expires_in": TICKET_TTL_SECONDS}


async def claim_ticket(ticket: str, *, redis: Redis) -> str | None:
    if not ticket:
        return None

    claimed = await redis.getdel(ticket_key(ticket))
    if claimed is None:
        return None
    return claimed.decode() if isinstance(claimed, bytes) else str(claimed)
