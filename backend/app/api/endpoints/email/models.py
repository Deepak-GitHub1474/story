from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class AddEmailRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr


class VerifyOtpRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    otp: Annotated[str, Field(min_length=4, max_length=8)]


class ResendRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")


class RemoveEmailRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    password: Annotated[str, Field(min_length=1, max_length=128)]


class ResetRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=1, max_length=20)]


class ResetVerifyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=1, max_length=20)]
    otp: Annotated[str, Field(min_length=4, max_length=8)]


class ResetCompleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reset_token: Annotated[str, Field(min_length=10, max_length=200)]
    new_password: Annotated[str, Field(min_length=10, max_length=128)]
    acknowledged_vault_loss: bool
