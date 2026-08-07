from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class UploadImageRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kind: Literal["image/jpeg", "image/png"]
    data: Annotated[str, Field(min_length=8, max_length=14_000_000)]
