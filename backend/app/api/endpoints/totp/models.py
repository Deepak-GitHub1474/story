from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class ConfirmTotpRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: Annotated[str, Field(min_length=6, max_length=6)]
