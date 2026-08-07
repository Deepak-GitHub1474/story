import re
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.api.endpoints.stories.constants import BODY_MAX, COMMENT_MAX, TITLE_MAX

MEDIA_URL = re.compile(r"^/v1/media/med_[0-9A-HJKMNP-TV-Z]{26}$")


class CreateStoryRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    title: Annotated[str, Field(max_length=TITLE_MAX)] | None = None
    body: Annotated[str, Field(max_length=BODY_MAX)] = ""
    shared_story_id: Annotated[str, Field(max_length=64)] | None = None
    images: Annotated[list[Annotated[str, Field(max_length=200)]], Field(max_length=8)] = []

    @field_validator("images")
    @classmethod
    def only_our_own_pictures(cls, value: list[str]) -> list[str]:
        for url in value:
            if not MEDIA_URL.match(url):
                raise ValueError("A story can only carry pictures uploaded to Story.")
        return value

    @model_validator(mode="after")
    def needs_words_or_something_to_share(self):
        if not self.body.strip() and self.shared_story_id is None:
            raise ValueError("A story needs words, or something to share.")
        return self


class UpdateStoryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: Annotated[str, Field(max_length=TITLE_MAX)] | None = None
    body: Annotated[str, Field(min_length=1, max_length=BODY_MAX)] | None = None
    images: (
        Annotated[list[Annotated[str, Field(max_length=200)]], Field(max_length=8)] | None
    ) = None

    @field_validator("images")
    @classmethod
    def only_our_own_pictures(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        for url in value:
            if not MEDIA_URL.match(url):
                raise ValueError("A story can only carry pictures uploaded to Story.")
        return value


class PublishStoryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    visibility: Literal["public", "private", "scheduled"]
    community_slug: str | None = None
    scheduled_for: datetime | None = None
    exposure_ack: bool = False


class UpdateCommentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    body: Annotated[str, Field(min_length=1, max_length=COMMENT_MAX)]


class CreateCommentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    body: Annotated[str, Field(min_length=1, max_length=COMMENT_MAX)]
    parent_id: str | None = None
