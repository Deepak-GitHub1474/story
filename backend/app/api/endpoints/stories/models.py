from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.api.endpoints.stories.constants import BODY_MAX, COMMENT_MAX, TITLE_MAX


class CreateStoryRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    title: Annotated[str, Field(max_length=TITLE_MAX)] | None = None
    body: Annotated[str, Field(min_length=1, max_length=BODY_MAX)]


class UpdateStoryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, Field(max_length=TITLE_MAX)] | None = None
    body: Annotated[str, Field(min_length=1, max_length=BODY_MAX)] | None = None


class PublishStoryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    visibility: Literal["public", "private"]
    community_slug: str | None = None


class CreateCommentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    body: Annotated[str, Field(min_length=1, max_length=COMMENT_MAX)]
    parent_id: str | None = None
