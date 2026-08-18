from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class RegisterPushTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    token: Annotated[str, Field(min_length=32, max_length=512)]
    platform: Literal["android", "ios"]


class ForgetPushTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    token: Annotated[str, Field(min_length=32, max_length=512)]
