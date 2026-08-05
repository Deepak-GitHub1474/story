from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class CreateReportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    target_kind: Literal["story", "comment", "user"]
    target_id: Annotated[str, Field(min_length=1, max_length=64)]
    reason: Literal[
        "harassment",
        "spam",
        "self_harm",
        "illegal",
        "impersonation",
        "wrong_community",
        "other",
    ]
    note: Annotated[str, Field(max_length=500)] | None = None
