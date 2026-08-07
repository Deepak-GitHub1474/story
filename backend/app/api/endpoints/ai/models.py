from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class PolishRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: Annotated[str, Field(min_length=1, max_length=20000)]
    instruction: Annotated[str, Field(min_length=1, max_length=400)]
