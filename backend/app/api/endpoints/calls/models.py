from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class StartCallRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    conversation_id: Annotated[str, Field(min_length=1, max_length=64)]


class DeleteCallsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    call_ids: Annotated[list[str], Field(default_factory=list, max_length=200)]
    all: bool = False


class RetentionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    days: Annotated[int, Field(ge=0, le=365)]
