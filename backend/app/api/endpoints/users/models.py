from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PrefsPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    theme: Literal["system", "midnight", "paper", "blush", "maroon"] | None = None
    reading_size: Literal["reading", "readingLg"] | None = None
    notify_in_app: bool | None = None
    notify_email: bool | None = None
    show_online_status: bool | None = None


class UpdateProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    display_name: Annotated[str, Field(min_length=1, max_length=40)] | None = None
    avatar_seed: Annotated[str, Field(pattern=r"^[0-9a-fA-F]{16}$")] | None = None
    bio: Annotated[str, Field(max_length=200)] | None = None
    interests: Annotated[list[str], Field(max_length=12)] | None = None
    prefs: PrefsPatch | None = None

    @field_validator("display_name")
    @classmethod
    def strip_display_name(cls, value: str | None) -> str | None:
        return value.strip() if value else value

    @field_validator("avatar_seed")
    @classmethod
    def normalize_avatar_seed(cls, value: str | None) -> str | None:
        return value.lower() if value else value


class ChangePasswordRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: Annotated[str, Field(min_length=1, max_length=128)]
    new_password: Annotated[str, Field(min_length=10, max_length=128)]
    otp: Annotated[str, Field(min_length=4, max_length=12)] | None = None


class DeactivateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    password: Annotated[str, Field(min_length=1, max_length=128)]


class DeleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    password: Annotated[str, Field(min_length=1, max_length=128)]
    acknowledged: bool


class CancelDeleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=1, max_length=20)]
    password: Annotated[str, Field(min_length=1, max_length=128)]
