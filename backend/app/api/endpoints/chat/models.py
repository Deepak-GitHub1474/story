from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from app.api.endpoints.chat import constants as c


class PublishIdentityRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    public_key: Annotated[str, Field(min_length=16, max_length=256)]


class StartConversationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=3, max_length=20)]
    wrapped_cek_for_me: Annotated[str, Field(min_length=16, max_length=512)]
    wrapped_cek_for_them: Annotated[str, Field(min_length=16, max_length=512)]
    sender_public_key: Annotated[str, Field(min_length=16, max_length=256)]


class SendMessageRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ciphertext: Annotated[str, Field(min_length=16, max_length=c.CIPHERTEXT_MAX_CHARS)]
    reply_to: str | None = None


class ReadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message_id: Annotated[str, Field(min_length=1, max_length=64)]


class ReactionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    emoji: Annotated[str, Field(min_length=1, max_length=c.EMOJI_MAX_CHARS)]
