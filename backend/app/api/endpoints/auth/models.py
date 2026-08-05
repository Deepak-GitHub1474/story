from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

USERNAME_PATTERN = r"^[a-z0-9_]{3,20}$"


class SignupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=3, max_length=20)]
    password: Annotated[str, Field(min_length=10, max_length=128)]
    tnc_accepted: bool
    referral_code: Annotated[str | None, Field(default=None, max_length=6)] = None

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("referral_code")
    @classmethod
    def normalize_referral_code(cls, value: str | None) -> str | None:
        return value.strip().upper() if value else None


class SigninRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=1, max_length=20)]
    password: Annotated[str, Field(min_length=1, max_length=128)]

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str) -> str:
        return value.strip().lower()


class UsernameAvailableRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: Annotated[str, Field(min_length=1, max_length=20)]

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str) -> str:
        return value.strip().lower()


class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str


class DeviceInfo(BaseModel):
    model_config = ConfigDict(extra="forbid")

    platform: Literal["ios", "android", "web"] = "web"
    os_version: str | None = Field(default=None, max_length=40)
    app_version: str | None = Field(default=None, max_length=20)
    device_model: str | None = Field(default=None, max_length=60)


class SigninWithDeviceRequest(SigninRequest):
    device: DeviceInfo = DeviceInfo()


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int


class UserOut(BaseModel):
    user_id: str
    username: str
    display_name: str
    avatar_seed: str
    role: str
    status: str
    blocked: bool
    referral_code: str
    referred_by: str | None
    bio: str | None
    interests: list[str]
    counts: dict
    prefs: dict
    onboarding: dict
    login_info: dict | None
    created_at: str
    last_login_at: str | None
