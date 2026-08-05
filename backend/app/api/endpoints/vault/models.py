from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class KdfParams(BaseModel):
    model_config = ConfigDict(extra="forbid")

    algo: Literal["argon2id"]
    memory_kib: Annotated[int, Field(ge=8192, le=1048576)]
    iterations: Annotated[int, Field(ge=1, le=10)]
    parallelism: Annotated[int, Field(ge=1, le=16)]


class InitKeysRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    salt_pw: Annotated[str, Field(min_length=8, max_length=128)]
    wrapped_umk: Annotated[str, Field(min_length=16, max_length=512)]
    kdf: KdfParams


class CreatePasscodeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: Annotated[str, Field(min_length=1, max_length=40)]
    scope: Literal["vault", "item"] = "vault"
    passcode_hash: Annotated[str, Field(min_length=16, max_length=256)]
    salt_pc: Annotated[str, Field(min_length=8, max_length=128)]
    kdf: KdfParams
    escrow_payload: Annotated[str, Field(min_length=8, max_length=1024)]
    hint: Annotated[str, Field(max_length=512)] | None = None


class CreateItemRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    passcode_id: str
    kind: Literal["image", "video", "document", "audio", "other"]
    size_bytes: Annotated[int, Field(gt=0)]
    chunk_count: Annotated[int, Field(gt=0, le=100000)]
    encrypted_metadata: Annotated[str, Field(min_length=8, max_length=8192)]
    wrapped_dek: Annotated[str, Field(min_length=16, max_length=512)]
    salt_item: Annotated[str, Field(min_length=8, max_length=128)]
    visibility: Literal["normal", "hidden"] = "normal"
    label_hash: Annotated[str, Field(min_length=32, max_length=128)] | None = None
    label_hint: Annotated[str, Field(max_length=512)] | None = None
    thumb_encrypted: Annotated[str, Field(max_length=65536)] | None = None


class CompleteItemRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    chunk_count: Annotated[int, Field(gt=0)]
    total_size: Annotated[int, Field(gt=0)]


class SearchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label_hash: Annotated[str, Field(min_length=32, max_length=128)]


class UpdateItemRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    encrypted_metadata: Annotated[str, Field(min_length=8, max_length=8192)] | None = None
    visibility: Literal["normal", "hidden"] | None = None
    label_hash: Annotated[str, Field(min_length=32, max_length=128)] | None = None
