from datetime import datetime
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.endpoints.chat import constants as c
from app.api.endpoints.connections import controllers as connection_controllers
from app.api.endpoints.notifications.service import notify
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.time import to_storage, to_wire, utc_now
from app.db import keys
from app.realtime import bus


def pair_key(first: str, second: str) -> str:
    return ":".join(sorted((first, second)))


async def _user_by_username(username: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    user = await mongo[c.USERS].find_one(
        {"username_lower": username.lower(), "deleted_at": None},
        {"_id": 1, "username": 1, "display_name": 1, "avatar_seed": 1, "blocked": 1},
    )
    if user is None or user.get("blocked"):
        raise api_error(ErrorCode.USER_NOT_FOUND)
    return user


async def _blocked_between(first: str, second: str, mongo: AsyncIOMotorDatabase) -> bool:
    found = await mongo[c.CONNECTIONS].find_one(
        {
            "status": "blocked",
            "$or": [
                {"follower_id": first, "followee_id": second},
                {"follower_id": second, "followee_id": first},
            ],
        },
        {"_id": 1},
    )
    return found is not None


async def _follows(follower: str, followee: str, mongo: AsyncIOMotorDatabase) -> bool:
    return await connection_controllers.is_following(follower, followee, mongo)


async def publish_identity(body, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    now = utc_now()
    await mongo[c.IDENTITIES].update_one(
        {"_id": claims.user_id},
        {
            "$set": {"public_key": body.public_key, "updated_at": now},
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )
    return {"public_key": body.public_key}


async def store_backup(body, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    now = utc_now()
    await mongo[c.IDENTITIES].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "public_key": body.public_key,
                "backup": {
                    "salt": body.salt,
                    "wrapped_private_key": body.wrapped_private_key,
                    "kdf": body.kdf.model_dump(),
                    "updated_at": now,
                },
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )
    return {"stored": True}


async def read_backup(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    identity = await mongo[c.IDENTITIES].find_one(
        {"_id": claims.user_id}, {"backup": 1, "public_key": 1}
    )
    backup = (identity or {}).get("backup")
    if backup is None:
        raise api_error(ErrorCode.CHAT_NO_BACKUP)

    return {
        "salt": backup["salt"],
        "wrapped_private_key": backup["wrapped_private_key"],
        "kdf": backup["kdf"],
        "public_key": identity["public_key"],
    }


async def forget_my_chats(user_id: str, *, mongo: AsyncIOMotorDatabase) -> None:
    now = utc_now()
    rooms = await mongo[c.CONVERSATIONS].distinct("_id", {"participant_ids": user_id})

    await mongo[c.KEYS].delete_many({"user_id": user_id})
    await mongo[c.READS].delete_many({"user_id": user_id})
    await mongo[c.IDENTITIES].delete_one({"_id": user_id})

    for room in rooms:
        await mongo[c.CONVERSATIONS].update_one(
            {"_id": room},
            {
                "$addToSet": {"deleted_by": user_id},
                "$set": {f"cleared_at.{user_id}": now},
            },
        )


async def read_identity(
    username: str | None, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    user_id = claims.user_id
    if username is not None:
        user_id = (await _user_by_username(username, mongo))["_id"]

    identity = await mongo[c.IDENTITIES].find_one({"_id": user_id}, {"public_key": 1})
    if identity is None:
        raise api_error(ErrorCode.CHAT_NO_IDENTITY)
    return {"public_key": identity["public_key"], "user_id": user_id}


def _other_id(conversation: dict[str, Any], user_id: str) -> str:
    return next(
        participant
        for participant in conversation["participant_ids"]
        if participant != user_id
    )


def _shows_presence(user: dict[str, Any] | None) -> bool:
    return (user or {}).get("prefs", {}).get("show_online_status", True)


async def _presence_of(viewer, peer, peer_id: str, redis) -> bool | None:
    if redis is None:
        return None
    if not _shows_presence(viewer) or not _shows_presence(peer):
        return None
    return await redis.get(keys.presence(peer_id)) is not None


async def _serialize_conversation(
    conversation: dict[str, Any],
    *,
    user_id: str,
    mongo: AsyncIOMotorDatabase,
    redis=None,
) -> dict[str, Any]:
    other_id = _other_id(conversation, user_id)
    other = await mongo[c.USERS].find_one(
        {"_id": other_id},
        {"username": 1, "display_name": 1, "avatar_seed": 1, "prefs": 1},
    )
    viewer = await mongo[c.USERS].find_one({"_id": user_id}, {"prefs": 1})

    key = await mongo[c.KEYS].find_one(
        {"_id": f"{conversation['_id']}:{user_id}"},
        {"wrapped_cek": 1, "sender_public_key": 1},
    )
    mine = await mongo[c.READS].find_one({"_id": f"{conversation['_id']}:{user_id}"})
    theirs = await mongo[c.READS].find_one({"_id": f"{conversation['_id']}:{other_id}"})

    unread = await mongo[c.MESSAGES].count_documents(
        {
            "conversation_id": conversation["_id"],
            "sender_id": {"$ne": user_id},
            "_id": {"$gt": (mine or {}).get("last_read_message_id", "")},
        }
    )

    return {
        "conversation_id": conversation["_id"],
        "state": conversation["state"],
        "is_requester": conversation.get("requested_by") == user_id,
        "other": {
            "user_id": other_id,
            "username": (other or {}).get("username", ""),
            "display_name": (other or {}).get("display_name", ""),
            "avatar_seed": (other or {}).get("avatar_seed", ""),
        },
        "wrapped_cek": (key or {}).get("wrapped_cek"),
        "sender_public_key": (key or {}).get("sender_public_key"),
        "unread_count": unread,
        "other_online": await _presence_of(viewer, other, other_id, redis),
        "other_typing": redis is not None
        and await redis.get(keys.typing(conversation["_id"], other_id)) is not None,
        "their_last_read_message_id": (theirs or {}).get("last_read_message_id"),
        "last_message_at": to_wire(conversation.get("last_message_at")),
        "created_at": to_wire(conversation.get("created_at")),
    }


async def people_to_message(
    *, claims, mongo: AsyncIOMotorDatabase, limit: int, cursor: str | None
) -> dict[str, Any]:
    limit = max(1, min(limit, 50))

    query: dict[str, Any] = {"follower_id": claims.user_id, "status": "active"}
    if cursor:
        query["_id"] = {"$lt": cursor}

    follows = (
        await mongo["connections"]
        .find(query, {"followee_id": 1})
        .sort("_id", -1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )

    has_more = len(follows) > limit
    page = follows[:limit]
    if not page:
        return {"items": [], "next_cursor": None, "has_more": False}

    ids = [row["followee_id"] for row in page]

    talking = await mongo[c.CONVERSATIONS].distinct(
        "participant_ids",
        {"participant_ids": claims.user_id, "deleted_by": {"$ne": claims.user_id}},
    )
    blocked = await connection_controllers.blocked_ids(claims.user_id, mongo)
    skip = set(talking) | set(blocked) | {claims.user_id}

    back = set(
        await mongo["connections"].distinct(
            "follower_id",
            {"follower_id": {"$in": ids}, "followee_id": claims.user_id, "status": "active"},
        )
    )

    people = await mongo[c.USERS].find(
        {"_id": {"$in": [uid for uid in ids if uid not in skip]}, "status": "active"},
        {"username": 1, "display_name": 1, "avatar_seed": 1},
    ).to_list(length=len(ids))
    by_id = {row["_id"]: row for row in people}

    items = []
    for user_id in ids:
        row = by_id.get(user_id)
        if row is None:
            continue
        items.append(
            {
                "user_id": row["_id"],
                "username": row.get("username"),
                "display_name": row.get("display_name", "Someone"),
                "avatar_seed": row.get("avatar_seed", ""),
                "opens_straight_away": user_id in back,
            }
        )

    items.sort(key=lambda row: not row["opens_straight_away"])

    return {
        "items": items,
        "next_cursor": page[-1]["_id"] if has_more else None,
        "has_more": has_more,
    }


async def start_conversation(
    body, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    other = await _user_by_username(body.username, mongo)
    if other["_id"] == claims.user_id:
        raise api_error(ErrorCode.CHAT_SELF, field="username")

    if await _blocked_between(claims.user_id, other["_id"], mongo):
        raise api_error(ErrorCode.CHAT_BLOCKED)

    key = pair_key(claims.user_id, other["_id"])
    existing = await mongo[c.CONVERSATIONS].find_one({"pair_key": key})
    if existing is not None:
        if claims.user_id in (existing.get("deleted_by") or []):
            await mongo[c.CONVERSATIONS].update_one(
                {"_id": existing["_id"]}, {"$pull": {"deleted_by": claims.user_id}}
            )
            existing["deleted_by"] = [
                who for who in existing["deleted_by"] if who != claims.user_id
            ]
        return {
            "conversation": await _serialize_conversation(
                existing, user_id=claims.user_id, mongo=mongo, redis=redis
            ),
            "created": False,
        }

    mutual = await _follows(claims.user_id, other["_id"], mongo) and await _follows(
        other["_id"], claims.user_id, mongo
    )

    now = utc_now()
    conversation = {
        "_id": new_id("cnv"),
        "pair_key": key,
        "participant_ids": sorted((claims.user_id, other["_id"])),
        "state": c.ACCEPTED if mutual else c.PENDING,
        "requested_by": None if mutual else claims.user_id,
        "last_message_at": now,
        "created_at": now,
        "updated_at": now,
    }
    await mongo[c.CONVERSATIONS].insert_one(conversation)

    await mongo[c.KEYS].insert_many(
        [
            {
                "_id": f"{conversation['_id']}:{claims.user_id}",
                "conversation_id": conversation["_id"],
                "user_id": claims.user_id,
                "wrapped_cek": body.wrapped_cek_for_me,
                "sender_public_key": body.sender_public_key,
                "created_at": now,
            },
            {
                "_id": f"{conversation['_id']}:{other['_id']}",
                "conversation_id": conversation["_id"],
                "user_id": other["_id"],
                "wrapped_cek": body.wrapped_cek_for_them,
                "sender_public_key": body.sender_public_key,
                "created_at": now,
            },
        ]
    )

    return {
        "conversation": await _serialize_conversation(
                conversation, user_id=claims.user_id, mongo=mongo, redis=redis
            ),
        "created": True,
    }


async def list_conversations(
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    state: str | None,
    redis=None,
    limit: int = c.CONVERSATION_LIMIT,
    cursor: str | None = None,
) -> dict[str, Any]:
    limit = max(1, min(limit, c.CONVERSATION_LIMIT))

    query: dict[str, Any] = {
        "participant_ids": claims.user_id,
        "deleted_by": {"$ne": claims.user_id},
    }
    if cursor:
        query["last_message_at"] = {"$lt": to_storage(datetime.fromisoformat(cursor))}

    if state == c.PENDING:
        query["state"] = c.PENDING
        query["requested_by"] = {"$ne": claims.user_id}
    else:
        query["$or"] = [{"state": c.ACCEPTED}, {"requested_by": claims.user_id}]

    docs = (
        await mongo[c.CONVERSATIONS]
        .find(query)
        .sort("last_message_at", -1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )
    has_more = len(docs) > limit
    docs = docs[:limit]

    return {
        "items": [
            await _serialize_conversation(
                doc, user_id=claims.user_id, mongo=mongo, redis=redis
            )
            for doc in docs
        ],
        "next_cursor": to_wire(docs[-1]["last_message_at"]) if docs and has_more else None,
        "has_more": has_more,
    }


async def _member_conversation(
    conversation_id: str, user_id: str, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    conversation = await mongo[c.CONVERSATIONS].find_one(
        {"_id": conversation_id, "participant_ids": user_id}
    )
    if conversation is None:
        raise api_error(ErrorCode.CONVERSATION_NOT_FOUND)
    return conversation


async def get_conversation(
    conversation_id: str, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    conversation = await _member_conversation(conversation_id, claims.user_id, mongo)
    return {
        "conversation": await _serialize_conversation(
                conversation, user_id=claims.user_id, mongo=mongo, redis=redis
            )
    }


async def accept_conversation(
    conversation_id: str, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    conversation = await _member_conversation(conversation_id, claims.user_id, mongo)
    if conversation.get("requested_by") == claims.user_id:
        raise api_error(ErrorCode.CHAT_NOT_YOURS_TO_ACCEPT)

    await mongo[c.CONVERSATIONS].update_one(
        {"_id": conversation_id},
        {"$set": {"state": c.ACCEPTED, "requested_by": None, "updated_at": utc_now()}},
    )
    return {"conversation_id": conversation_id, "state": c.ACCEPTED}


async def reject_conversation(
    conversation_id: str, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    conversation = await _member_conversation(conversation_id, claims.user_id, mongo)
    if conversation.get("state") != c.PENDING:
        raise api_error(ErrorCode.CHAT_ALREADY_OPEN)
    if conversation.get("requested_by") == claims.user_id:
        raise api_error(ErrorCode.CHAT_NOT_YOURS_TO_ACCEPT)

    await mongo[c.MESSAGES].delete_many({"conversation_id": conversation_id})
    await mongo[c.KEYS].delete_many({"conversation_id": conversation_id})
    await mongo[c.CONVERSATIONS].delete_one({"_id": conversation_id})
    return {"conversation_id": conversation_id, "rejected": True}


async def delete_conversation(
    conversation_id: str, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)
    await mongo[c.CONVERSATIONS].update_one(
        {"_id": conversation_id},
        {
            "$addToSet": {"deleted_by": claims.user_id},
            "$set": {f"cleared_at.{claims.user_id}": utc_now()},
        },
    )
    return {"conversation_id": conversation_id, "deleted": True}


async def edit_message(
    conversation_id: str,
    message_id: str,
    body,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    redis=None,
) -> dict[str, Any]:
    conversation = await _member_conversation(conversation_id, claims.user_id, mongo)

    message = await mongo[c.MESSAGES].find_one(
        {"_id": message_id, "conversation_id": conversation_id}
    )
    if message is None or message.get("deleted_at") is not None:
        raise api_error(ErrorCode.MESSAGE_NOT_FOUND)
    if message["sender_id"] != claims.user_id:
        raise api_error(ErrorCode.CHAT_NOT_YOURS_TO_ACCEPT)

    now = utc_now()
    age = (now - message["created_at"]).total_seconds()
    if age > c.EDIT_WINDOW_SECONDS:
        raise api_error(ErrorCode.EDIT_WINDOW_CLOSED)

    await mongo[c.MESSAGES].update_one(
        {"_id": message_id},
        {"$set": {"ciphertext": body.ciphertext, "edited_at": now}},
    )
    message["ciphertext"] = body.ciphertext
    message["edited_at"] = now

    payload = _serialize_message(message)
    if redis is not None:
        await bus.publish(
            redis,
            [_other_id(conversation, claims.user_id)],
            {"type": "edited", "conversation_id": conversation_id, "message": payload},
        )

    return {"message": payload}


async def hide_message(
    conversation_id: str, message_id: str, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)

    result = await mongo[c.MESSAGES].update_one(
        {"_id": message_id, "conversation_id": conversation_id},
        {"$addToSet": {"hidden_by": claims.user_id}},
    )
    if result.matched_count == 0:
        raise api_error(ErrorCode.MESSAGE_NOT_FOUND)

    return {"message_id": message_id, "hidden": True}


async def rekey_conversation(
    conversation_id: str, body, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    conversation = await _member_conversation(conversation_id, claims.user_id, mongo)
    other_id = _other_id(conversation, claims.user_id)
    now = utc_now()

    for user_id, wrapped in (
        (claims.user_id, body.wrapped_cek_for_me),
        (other_id, body.wrapped_cek_for_them),
    ):
        await mongo[c.KEYS].update_one(
            {"_id": f"{conversation_id}:{user_id}"},
            {
                "$set": {
                    "conversation_id": conversation_id,
                    "user_id": user_id,
                    "wrapped_cek": wrapped,
                    "sender_public_key": body.sender_public_key,
                    "created_at": now,
                }
            },
            upsert=True,
        )

    await mongo[c.MESSAGES].delete_many({"conversation_id": conversation_id})
    await mongo[c.READS].delete_many({"conversation_id": conversation_id})
    await mongo[c.CONVERSATIONS].update_one(
        {"_id": conversation_id}, {"$set": {"updated_at": now}}
    )

    return {"conversation_id": conversation_id, "rekeyed": True}


def _serialize_message(doc: dict[str, Any]) -> dict[str, Any]:
    is_deleted = doc.get("deleted_at") is not None
    return {
        "message_id": doc["_id"],
        "conversation_id": doc["conversation_id"],
        "sender_id": doc["sender_id"],
        "ciphertext": None if is_deleted else doc["ciphertext"],
        "reply_to": doc.get("reply_to"),
        "is_deleted": is_deleted,
        "reactions": [
            {"user_id": user_id, "emoji": emoji}
            for user_id, emoji in (doc.get("reactions") or {}).items()
        ],
        "created_at": to_wire(doc.get("created_at")),
        "edited_at": to_wire(doc.get("edited_at")) if doc.get("edited_at") else None,
    }


async def send_message(
    conversation_id: str, body, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    conversation = await _member_conversation(conversation_id, claims.user_id, mongo)

    other_id = _other_id(conversation, claims.user_id)
    if await _blocked_between(claims.user_id, other_id, mongo):
        raise api_error(ErrorCode.CHAT_BLOCKED)

    now = utc_now()
    message = {
        "_id": new_id("msg"),
        "conversation_id": conversation_id,
        "sender_id": claims.user_id,
        "ciphertext": body.ciphertext,
        "reply_to": body.reply_to,
        "reactions": {},
        "created_at": now,
        "deleted_at": None,
    }
    await mongo[c.MESSAGES].insert_one(message)
    await mongo[c.CONVERSATIONS].update_one(
        {"_id": conversation_id},
        {"$set": {"last_message_at": now, "updated_at": now}, "$pull": {"deleted_by": other_id}},
    )

    sender = await mongo[c.USERS].find_one(
        {"_id": claims.user_id}, {"display_name": 1, "avatar_seed": 1, "username": 1}
    )
    await notify(
        mongo=mongo,
        user_id=other_id,
        actor_id=claims.user_id,
        actor_snapshot={
            "display_name": (sender or {}).get("display_name", "Someone"),
            "avatar_seed": (sender or {}).get("avatar_seed", ""),
            "username": (sender or {}).get("username"),
        },
        kind="chat_message",
        target_kind="conversation",
        target_id=conversation_id,
        body="New message",
        collapse=True,
        feed=False,
        redis=redis,
    )

    payload = _serialize_message(message)
    if redis is not None:
        await bus.publish(
            redis,
            [other_id],
            {"type": "message", "conversation_id": conversation_id, "message": payload},
        )

    return {"message": payload}


async def list_messages(
    conversation_id: str,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    limit: int,
    cursor: str | None,
    after: str | None,
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)
    limit = max(1, min(limit, c.MESSAGE_MAX_LIMIT))

    query: dict[str, Any] = {
        "conversation_id": conversation_id,
        "hidden_by": {"$ne": claims.user_id},
    }

    conversation = await mongo[c.CONVERSATIONS].find_one(
        {"_id": conversation_id}, {"cleared_at": 1}
    )
    cleared = (conversation or {}).get("cleared_at", {}).get(claims.user_id)
    if cleared is not None:
        query["created_at"] = {"$gt": cleared}

    if after:
        query["_id"] = {"$gt": after}
        docs = (
            await mongo[c.MESSAGES]
            .find(query)
            .sort("_id", 1)
            .limit(limit)
            .to_list(length=limit)
        )
        return {
            "items": [_serialize_message(doc) for doc in docs],
            "next_cursor": None,
            "has_more": False,
        }

    if cursor:
        query["_id"] = {"$lt": cursor}

    docs = (
        await mongo[c.MESSAGES]
        .find(query)
        .sort("_id", -1)
        .limit(limit + 1)
        .to_list(length=limit + 1)
    )
    has_more = len(docs) > limit
    page = docs[:limit]

    return {
        "items": [_serialize_message(doc) for doc in page],
        "next_cursor": page[-1]["_id"] if page and has_more else None,
        "has_more": has_more,
    }


async def unsend_message(
    conversation_id: str, message_id: str, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)

    message = await mongo[c.MESSAGES].find_one(
        {"_id": message_id, "conversation_id": conversation_id}, {"sender_id": 1}
    )
    if message is None:
        raise api_error(ErrorCode.MESSAGE_NOT_FOUND)
    if message["sender_id"] != claims.user_id:
        raise api_error(ErrorCode.CHAT_NOT_YOURS_TO_ACCEPT)

    await mongo[c.MESSAGES].delete_one({"_id": message_id})

    if redis is not None:
        conversation = await mongo[c.CONVERSATIONS].find_one(
            {"_id": conversation_id}, {"participant_ids": 1}
        )
        if conversation is not None:
            await bus.publish(
                redis,
                [_other_id(conversation, claims.user_id)],
                {
                    "type": "unsent",
                    "conversation_id": conversation_id,
                    "message_id": message_id,
                },
            )

    return {"message_id": message_id, "deleted": True}


async def set_reaction(
    conversation_id: str, message_id: str, body, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)
    result = await mongo[c.MESSAGES].update_one(
        {"_id": message_id, "conversation_id": conversation_id, "deleted_at": None},
        {"$set": {f"reactions.{claims.user_id}": body.emoji}},
    )
    if result.matched_count == 0:
        raise api_error(ErrorCode.MESSAGE_NOT_FOUND)
    await _push_reaction(conversation_id, message_id, claims, mongo, redis)
    return {"message_id": message_id, "emoji": body.emoji}


async def clear_reaction(
    conversation_id: str, message_id: str, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)
    await mongo[c.MESSAGES].update_one(
        {"_id": message_id, "conversation_id": conversation_id},
        {"$unset": {f"reactions.{claims.user_id}": ""}},
    )
    await _push_reaction(conversation_id, message_id, claims, mongo, redis)
    return {"message_id": message_id, "emoji": None}


async def _push_reaction(conversation_id, message_id, claims, mongo, redis) -> None:
    if redis is None:
        return

    conversation = await mongo[c.CONVERSATIONS].find_one(
        {"_id": conversation_id}, {"participant_ids": 1}
    )
    message = await mongo[c.MESSAGES].find_one({"_id": message_id})
    if conversation is None or message is None:
        return

    await bus.publish(
        redis,
        [_other_id(conversation, claims.user_id)],
        {
            "type": "reaction",
            "conversation_id": conversation_id,
            "message": _serialize_message(message),
        },
    )


async def mark_read(
    conversation_id: str, body, *, claims, mongo: AsyncIOMotorDatabase, redis=None
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)
    now = utc_now()
    await mongo[c.READS].update_one(
        {"_id": f"{conversation_id}:{claims.user_id}"},
        {
            "$set": {
                "conversation_id": conversation_id,
                "user_id": claims.user_id,
                "last_read_message_id": body.message_id,
                "updated_at": now,
            }
        },
        upsert=True,
    )
    if redis is not None:
        conversation = await mongo[c.CONVERSATIONS].find_one(
            {"_id": conversation_id}, {"participant_ids": 1}
        )
        if conversation is not None:
            await bus.publish(
                redis,
                [_other_id(conversation, claims.user_id)],
                {
                    "type": "read",
                    "conversation_id": conversation_id,
                    "message_id": body.message_id,
                },
            )

    return {"conversation_id": conversation_id, "last_read_message_id": body.message_id}


async def unread_count(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    conversations = (
        await mongo[c.CONVERSATIONS]
        .find(
            {
                "participant_ids": claims.user_id,
                "deleted_by": {"$ne": claims.user_id},
                "$or": [{"state": c.ACCEPTED}, {"requested_by": claims.user_id}],
            },
            {"_id": 1},
        )
        .to_list(length=c.CONVERSATION_LIMIT)
    )

    unread = 0
    for conversation in conversations:
        mine = await mongo[c.READS].find_one({"_id": f"{conversation['_id']}:{claims.user_id}"})
        unread += await mongo[c.MESSAGES].count_documents(
            {
                "conversation_id": conversation["_id"],
                "sender_id": {"$ne": claims.user_id},
                "_id": {"$gt": (mine or {}).get("last_read_message_id", "")},
            }
        )

    requests = await mongo[c.CONVERSATIONS].count_documents(
        {
            "participant_ids": claims.user_id,
            "state": c.PENDING,
            "requested_by": {"$ne": claims.user_id},
            "deleted_by": {"$ne": claims.user_id},
        }
    )

    return {"unread": unread, "requests": requests}


async def mark_online(user_id: str, *, redis) -> None:
    await redis.set(keys.presence(user_id), "1", ex=c.PRESENCE_TTL_SECONDS)


async def mark_offline(user_id: str, *, redis) -> None:
    await redis.delete(keys.presence(user_id))


async def heartbeat(*, claims, redis) -> dict[str, Any]:
    await mark_online(claims.user_id, redis=redis)
    return {"online": True}


async def typing_from_socket(
    conversation_id: str, *, user_id: str, mongo: AsyncIOMotorDatabase, redis
) -> None:
    conversation = await mongo[c.CONVERSATIONS].find_one(
        {"_id": conversation_id, "participant_ids": user_id}, {"participant_ids": 1}
    )
    if conversation is None:
        return

    await redis.set(
        keys.typing(conversation_id, user_id), "1", ex=c.TYPING_TTL_SECONDS
    )
    await bus.publish(
        redis,
        [_other_id(conversation, user_id)],
        {"type": "typing", "conversation_id": conversation_id},
    )


async def set_typing(
    conversation_id: str, *, claims, mongo: AsyncIOMotorDatabase, redis
) -> dict[str, Any]:
    await _member_conversation(conversation_id, claims.user_id, mongo)
    await redis.set(
        keys.typing(conversation_id, claims.user_id), "1", ex=c.TYPING_TTL_SECONDS
    )

    conversation = await mongo[c.CONVERSATIONS].find_one(
        {"_id": conversation_id}, {"participant_ids": 1}
    )
    if conversation is not None:
        await bus.publish(
            redis,
            [_other_id(conversation, claims.user_id)],
            {"type": "typing", "conversation_id": conversation_id},
        )

    return {"typing": True}
