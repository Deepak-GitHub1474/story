from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.api.endpoints.vault import controllers
from app.api.endpoints.vault.models import (
    ChangeMasterKeyRequest,
    ChangeVaultKeyRequest,
    CompleteItemRequest,
    CreateItemRequest,
    CreatePasscodeRequest,
    InitKeysRequest,
    RenameVaultRequest,
    SearchRequest,
    UpdateItemRequest,
)
from app.core.deps import AppSettings, CurrentClaims, rate_limit_dep
from app.db.mongo import MongoDatabase
from app.ports.factory import build_storage
from app.ports.storage import StoragePort
from app.responses import ok_response


def _storage(settings: AppSettings) -> StoragePort:
    return build_storage(settings)


Storage = Annotated[StoragePort, Depends(_storage)]

router = APIRouter(tags=["vault"])


@router.post("/users/me/keys", status_code=status.HTTP_201_CREATED)
async def init_keys(body: InitKeysRequest, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.init_keys(body, claims=claims, mongo=mongo)
    return ok_response("Your keys are set up.", data=data)


@router.get("/users/me/keys", status_code=status.HTTP_200_OK)
async def get_keys(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.get_keys(claims=claims, mongo=mongo)
    return ok_response("Keys loaded.", data=data)


@router.get("/vault/overview", status_code=status.HTTP_200_OK)
async def overview(claims: CurrentClaims, mongo: MongoDatabase, settings: AppSettings):
    data = await controllers.overview(claims=claims, mongo=mongo, settings=settings)
    return ok_response("Vault overview.", data=data)


@router.get("/vault/passcodes", status_code=status.HTTP_200_OK)
async def list_passcodes(claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.list_passcodes(claims=claims, mongo=mongo)
    return ok_response("Passcodes.", data=data)


@router.post("/vault/passcodes", status_code=status.HTTP_201_CREATED)
async def create_passcode(body: CreatePasscodeRequest, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.create_passcode(body, claims=claims, mongo=mongo)
    return ok_response("Passcode created.", data=data)


@router.put("/users/me/keys", status_code=status.HTTP_200_OK)
async def change_master_key(
    body: ChangeMasterKeyRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.change_master_key(body, claims=claims, mongo=mongo)
    return ok_response("Main passcode changed.", data=data)


@router.put("/vault/passcodes/{passcode_id}/key", status_code=status.HTTP_200_OK)
async def change_vault_key(
    passcode_id: str,
    body: ChangeVaultKeyRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.change_vault_key(passcode_id, body, claims=claims, mongo=mongo)
    return ok_response("Vault passcode changed.", data=data)


@router.patch("/vault/passcodes/{passcode_id}", status_code=status.HTTP_200_OK)
async def rename_vault(
    passcode_id: str,
    body: RenameVaultRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.rename_vault(passcode_id, body, claims=claims, mongo=mongo)
    return ok_response("Vault renamed.", data=data)


@router.delete("/vault/passcodes/{passcode_id}", status_code=status.HTTP_200_OK)
async def delete_vault(
    passcode_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    storage: Storage,
):
    data = await controllers.delete_vault(
        passcode_id, claims=claims, mongo=mongo, storage=storage
    )
    return ok_response("Vault deleted.", data=data)


@router.get("/vault/items", status_code=status.HTTP_200_OK)
async def list_items(
    claims: CurrentClaims, mongo: MongoDatabase, passcode_id: str | None = None
):
    data = await controllers.list_items(claims=claims, mongo=mongo, passcode_id=passcode_id)
    return ok_response("Vault items.", data=data)


@router.post(
    "/vault/items",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_dep("vault_upload", 100, 3600))],
)
async def create_item(
    body: CreateItemRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    storage: Storage,
    settings: AppSettings,
):
    data = await controllers.create_item(
        body, claims=claims, mongo=mongo, storage=storage, settings=settings
    )
    return ok_response("Ready for upload.", data=data)


@router.post("/vault/items/{item_id}/complete", status_code=status.HTTP_202_ACCEPTED)
async def complete_item(
    item_id: str,
    body: CompleteItemRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    storage: Storage,
):
    data = await controllers.complete_item(
        item_id, body, claims=claims, mongo=mongo, storage=storage
    )
    return ok_response("Upload confirmed.", data=data)


@router.post(
    "/vault/search",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(rate_limit_dep("vault_search", 20, 60))],
)
async def search(body: SearchRequest, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.search(body.label_hash, claims=claims, mongo=mongo)
    return ok_response("Item found.", data=data)


@router.get("/vault/items/{item_id}", status_code=status.HTTP_200_OK)
async def get_item(item_id: str, claims: CurrentClaims, mongo: MongoDatabase):
    data = await controllers.get_item(item_id, claims=claims, mongo=mongo)
    return ok_response("Item loaded.", data=data)


@router.get("/vault/items/{item_id}/download", status_code=status.HTTP_200_OK)
async def download(
    item_id: str,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    storage: Storage,
    settings: AppSettings,
):
    data = await controllers.download_url(
        item_id, claims=claims, mongo=mongo, storage=storage, settings=settings
    )
    return ok_response("Download ready.", data=data)


@router.patch("/vault/items/{item_id}", status_code=status.HTTP_200_OK)
async def update_item(
    item_id: str, body: UpdateItemRequest, claims: CurrentClaims, mongo: MongoDatabase
):
    data = await controllers.update_item(item_id, body, claims=claims, mongo=mongo)
    return ok_response("Item updated.", data=data)


@router.delete("/vault/items/{item_id}", status_code=status.HTTP_200_OK)
async def delete_item(item_id: str, claims: CurrentClaims, mongo: MongoDatabase, storage: Storage):
    data = await controllers.delete_item(item_id, claims=claims, mongo=mongo, storage=storage)
    return ok_response("Item deleted.", data=data)
