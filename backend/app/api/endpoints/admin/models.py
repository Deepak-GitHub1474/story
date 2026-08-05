from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class ResolveReportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    outcome: Literal["actioned", "dismissed"]
    note: Annotated[str, Field(max_length=500)] | None = None


class BlockUserRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: Annotated[str, Field(min_length=1, max_length=200)]
