from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class CreateTicketRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal[
        "passcode_release",
        "account_locked",
        "content_appeal",
        "data_export",
        "account_deletion",
        "security_incident",
    ]
    reason: Annotated[str, Field(min_length=10, max_length=1000)]


class ReleaseEscrowRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ticket_id: str
    justification: Annotated[str, Field(min_length=50, max_length=1000)]
