from fastapi import APIRouter, Query, Response, status

from app.api.endpoints.chat import constants as c
from app.api.endpoints.chat import controllers
from app.api.endpoints.chat.models import (
    EditMessageRequest,
    PublishIdentityRequest,
    ReactionRequest,
    ReadRequest,
    RekeyRequest,
    SendMessageRequest,
    StartConversationRequest,
    StoreBackupRequest,
)
from app.core.deps import CurrentClaims
from app.db.mongo import MongoDatabase
from app.db.redis import RedisClient
from app.responses import ok_response

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("/identity", status_code=status.HTTP_200_OK)
async def publish_identity(
    body: PublishIdentityRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.publish_identity(body, claims=claims, mongo=mongo)
    return ok_response("Chat key published.", data=data)


@router.post("/backup", status_code=status.HTTP_200_OK)
async def store_backup(
    body: StoreBackupRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.store_backup(body, claims=claims, mongo=mongo)
    return ok_response("Chat key backed up.", data=data)


@router.get("/backup", status_code=status.HTTP_200_OK)
async def read_backup(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.read_backup(claims=claims, mongo=mongo)
    return ok_response("Chat key backup.", data=data)


@router.get("/identity", status_code=status.HTTP_200_OK)
async def read_own_identity(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.read_identity(None, claims=claims, mongo=mongo)
    return ok_response("Chat key.", data=data)


@router.get("/identity/{username}", status_code=status.HTTP_200_OK)
async def read_identity(username: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.read_identity(username, claims=claims, mongo=mongo)
    return ok_response("Chat key.", data=data)


@router.post("/presence", status_code=status.HTTP_200_OK)
async def heartbeat(claims: CurrentClaims, redis: RedisClient):
    data = await controllers.heartbeat(claims=claims, redis=redis)
    return ok_response("Online.", data=data)


@router.post("/conversations/{conversation_id}/typing", status_code=status.HTTP_200_OK)
async def set_typing(
    conversation_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.set_typing(
        conversation_id, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Typing.", data=data)


@router.get("/unread-count", status_code=status.HTTP_200_OK)
async def unread_count(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.unread_count(claims=claims, mongo=mongo)
    return ok_response("Unread chats.", data=data)


@router.get("/people", status_code=status.HTTP_200_OK)
async def people_to_message(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = 20,
    cursor: str | None = None,
):
    data = await controllers.people_to_message(
        claims=claims, mongo=mongo, limit=limit, cursor=cursor
    )
    return ok_response("People you follow.", data=data)


@router.post("/conversations", status_code=status.HTTP_201_CREATED)
async def start_conversation(
    body: StartConversationRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
    response: Response,
):
    data = await controllers.start_conversation(
        body, claims=claims, mongo=mongo, redis=redis
    )
    if not data["created"]:
        response.status_code = status.HTTP_200_OK
        return ok_response("Conversation already open.", data=data)
    return ok_response("Conversation open.", data=data)


@router.get("/conversations", status_code=status.HTTP_200_OK)
async def list_conversations(
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
    state: str | None = Query(default=None),
    limit: int = 20,
    cursor: str | None = None,
):
    data = await controllers.list_conversations(
        claims=claims,
        mongo=mongo,
        state=state,
        redis=redis,
        limit=limit,
        cursor=cursor,
    )
    return ok_response("Chats loaded.", data=data)


@router.get("/conversations/{conversation_id}", status_code=status.HTTP_200_OK)
async def get_conversation(
    conversation_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.get_conversation(
        conversation_id, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Chat loaded.", data=data)


@router.post("/conversations/{conversation_id}/accept", status_code=status.HTTP_200_OK)
async def accept_conversation(
    conversation_id: str, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.accept_conversation(conversation_id, claims=claims, mongo=mongo)
    return ok_response("Request accepted.", data=data)


@router.post("/conversations/{conversation_id}/reject", status_code=status.HTTP_200_OK)
async def reject_conversation(
    conversation_id: str, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.reject_conversation(
        conversation_id, claims=claims, mongo=mongo
    )
    return ok_response("Request turned down.", data=data)


@router.put("/conversations/{conversation_id}/keys", status_code=status.HTTP_200_OK)
async def rekey_conversation(
    conversation_id: str,
    body: RekeyRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.rekey_conversation(
        conversation_id, body, claims=claims, mongo=mongo
    )
    return ok_response("Chat key reset. Earlier messages are gone.", data=data)


@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_200_OK)
async def delete_conversation(
    conversation_id: str, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.delete_conversation(conversation_id, claims=claims, mongo=mongo)
    return ok_response("Chat removed.", data=data)


@router.post("/conversations/{conversation_id}/messages", status_code=status.HTTP_201_CREATED)
async def send_message(
    conversation_id: str,
    body: SendMessageRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.send_message(
        conversation_id, body, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Sent.", data=data)


@router.get("/conversations/{conversation_id}/messages", status_code=status.HTTP_200_OK)
async def list_messages(
    conversation_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    limit: int = Query(default=c.MESSAGE_DEFAULT_LIMIT, ge=1, le=c.MESSAGE_MAX_LIMIT),
    cursor: str | None = Query(default=None),
    after: str | None = Query(default=None),
):
    data = await controllers.list_messages(
        conversation_id, claims=claims, mongo=mongo, limit=limit, cursor=cursor, after=after
    )
    return ok_response("Messages loaded.", data=data)


@router.delete(
    "/conversations/{conversation_id}/messages/{message_id}", status_code=status.HTTP_200_OK
)
async def unsend_message(
    conversation_id: str,
    message_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.unsend_message(
        conversation_id, message_id, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Unsent.", data=data)


@router.post(
    "/conversations/{conversation_id}/messages/{message_id}/reaction",
    status_code=status.HTTP_200_OK,
)
async def set_reaction(
    conversation_id: str,
    message_id: str,
    body: ReactionRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.set_reaction(
        conversation_id, message_id, body, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Reacted.", data=data)


@router.delete(
    "/conversations/{conversation_id}/messages/{message_id}/reaction",
    status_code=status.HTTP_200_OK,
)
async def clear_reaction(
    conversation_id: str,
    message_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.clear_reaction(
        conversation_id, message_id, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Reaction removed.", data=data)


@router.post("/conversations/{conversation_id}/read", status_code=status.HTTP_200_OK)
async def mark_read(
    conversation_id: str,
    body: ReadRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.mark_read(
        conversation_id, body, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Marked read.", data=data)


@router.patch(
    "/conversations/{conversation_id}/messages/{message_id}",
    status_code=status.HTTP_200_OK,
)
async def edit_message(
    conversation_id: str,
    message_id: str,
    body: EditMessageRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    redis: RedisClient,
):
    data = await controllers.edit_message(
        conversation_id, message_id, body, claims=claims, mongo=mongo, redis=redis
    )
    return ok_response("Message updated.", data=data)


@router.delete(
    "/conversations/{conversation_id}/messages/{message_id}/mine",
    status_code=status.HTTP_200_OK,
)
async def hide_message(
    conversation_id: str,
    message_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.hide_message(
        conversation_id, message_id, claims=claims, mongo=mongo
    )
    return ok_response("Removed for you.", data=data)
