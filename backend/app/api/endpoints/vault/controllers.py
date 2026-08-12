from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError

from app.api.endpoints.vault import constants as c
from app.api.endpoints.vault.models import (
    ChangeMasterKeyRequest,
    ChangeVaultKeyRequest,
    CompleteItemRequest,
    CreateItemRequest,
    CreatePasscodeRequest,
    InitKeysRequest,
    RenameVaultRequest,
    UpdateItemRequest,
)
from app.config import Settings
from app.core.errors import ErrorCode, api_error
from app.core.ids import new_id
from app.core.time import to_wire, utc_now
from app.ports.storage import StoragePort


def serialize_item(doc: dict[str, Any]) -> dict[str, Any]:
    payload = {
        "item_id": doc["_id"],
        "kind": doc["kind"],
        "size_bytes": doc["size_bytes"],
        "chunk_count": doc["chunk_count"],
        "encrypted_metadata": doc["encrypted_metadata"],
        "thumb_encrypted": doc.get("thumb_encrypted"),
        "visibility": doc["visibility"],
        "status": doc["status"],
        "scan_state": doc.get("scan_state", "pending"),
        "key_state": doc.get("key_state", "active"),
        "created_at": to_wire(doc.get("created_at")),
    }
    payload["wrapped_dek"] = doc.get("wrapped_dek")
    payload["salt_item"] = doc.get("salt_item")
    payload["crypto_version"] = doc.get("crypto_version", "story.dek.v1")
    return payload


async def _require_keys(user_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    keys = await mongo[c.USER_KEYS].find_one({"_id": user_id, "wrapped_umk": {"$ne": None}})
    if keys is None or not keys.get("wrapped_umk"):
        raise api_error(ErrorCode.KEYS_NOT_INITIALIZED)
    return keys


async def init_keys(
    body: InitKeysRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    existing = await mongo[c.USER_KEYS].find_one({"_id": claims.user_id}, {"wrapped_umk": 1})
    if existing and existing.get("wrapped_umk"):
        raise api_error(ErrorCode.KEYS_ALREADY_INITIALIZED)

    now = utc_now()
    await mongo[c.USER_KEYS].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "user_id": claims.user_id,
                "salt_pw": body.salt_pw,
                "wrapped_umk": body.wrapped_umk,
                "kdf": body.kdf.model_dump(),
                "umk_version": 1,
                "label_key_version": 1,
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )
    return {"keys_initialized": True}


async def get_keys(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    keys = await _require_keys(claims.user_id, mongo)
    return {
        "salt_pw": keys["salt_pw"],
        "wrapped_umk": keys["wrapped_umk"],
        "kdf": keys.get("kdf", {}),
        "umk_version": keys.get("umk_version", 1),
        "label_key_version": keys.get("label_key_version", 1),
    }


async def create_passcode(
    body: CreatePasscodeRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    if body.key_source == "master":
        await _require_keys(claims.user_id, mongo)
    elif body.wrapped_umk is None:
        raise api_error(ErrorCode.VALIDATION_FAILED, field="wrapped_umk")

    now = utc_now()
    passcode = {
        "_id": new_id("pcd"),
        "user_id": claims.user_id,
        "label": body.label,
        "scope": body.scope,
        "passcode_hash": body.passcode_hash,
        "salt_pc": body.salt_pc,
        "kdf": body.kdf.model_dump(),
        "escrow_ciphertext": body.escrow_payload,
        "escrow_key_id": "local-dev",
        "key_source": body.key_source,
        "wrapped_umk": body.wrapped_umk,
        "crypto_version": 2,
        "hint": body.hint,
        "failed_attempts": 0,
        "locked_until": None,
        "last_used_at": None,
        "created_at": now,
        "updated_at": now,
    }

    try:
        await mongo[c.PASSCODES].insert_one(passcode)
    except DuplicateKeyError as exc:
        raise api_error(ErrorCode.PASSCODE_LABEL_TAKEN, field="label") from exc

    return {
        "passcode": {
            "passcode_id": passcode["_id"],
            "label": passcode["label"],
            "scope": passcode["scope"],
            "key_source": passcode["key_source"],
            "salt_pc": passcode["salt_pc"],
            "wrapped_umk": passcode["wrapped_umk"],
            "kdf": passcode["kdf"],
            "crypto_version": 2,
            "created_at": to_wire(now),
        }
    }


async def _owned_vault(passcode_id: str, user_id: str, mongo: AsyncIOMotorDatabase) -> dict:
    vault = await mongo[c.PASSCODES].find_one({"_id": passcode_id, "user_id": user_id})
    if vault is None:
        raise api_error(ErrorCode.PASSCODE_NOT_FOUND)
    return vault


async def rename_vault(
    passcode_id: str, body: RenameVaultRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    vault = await _owned_vault(passcode_id, claims.user_id, mongo)

    try:
        await mongo[c.PASSCODES].update_one(
            {"_id": passcode_id},
            {"$set": {"label": body.label, "updated_at": utc_now()}},
        )
    except DuplicateKeyError as exc:
        raise api_error(ErrorCode.PASSCODE_LABEL_TAKEN, field="label") from exc

    return {
        "passcode": {
            "passcode_id": passcode_id,
            "label": body.label,
            "scope": vault["scope"],
            "created_at": to_wire(vault["created_at"]),
        }
    }


async def change_master_key(
    body: ChangeMasterKeyRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    await _require_keys(claims.user_id, mongo)

    await mongo[c.USER_KEYS].update_one(
        {"_id": claims.user_id},
        {
            "$set": {
                "salt_pw": body.salt_pw,
                "wrapped_umk": body.wrapped_umk,
                "kdf": body.kdf.model_dump(),
                "updated_at": utc_now(),
            }
        },
    )
    return {"key_changed": True}


async def change_vault_key(
    passcode_id: str, body: ChangeVaultKeyRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    vault = await _owned_vault(passcode_id, claims.user_id, mongo)
    if vault.get("key_source", "master") != "own":
        raise api_error(ErrorCode.VAULT_USES_MASTER_KEY)

    await mongo[c.PASSCODES].update_one(
        {"_id": passcode_id},
        {
            "$set": {
                "salt_pc": body.salt_pc,
                "wrapped_umk": body.wrapped_umk,
                "kdf": body.kdf.model_dump(),
                "updated_at": utc_now(),
            }
        },
    )
    return {"key_changed": True}


async def delete_vault(
    passcode_id: str, *, claims, mongo: AsyncIOMotorDatabase, storage: StoragePort
) -> dict[str, Any]:
    await _owned_vault(passcode_id, claims.user_id, mongo)

    owned = {"user_id": claims.user_id, "passcode_id": passcode_id}
    removed = 0
    async for item in mongo[c.VAULT_ITEMS].find(owned, {"object_key": 1}):
        if item.get("object_key"):
            await storage.delete(profile=c.VAULT_PROFILE, key=item["object_key"])
        removed += 1

    await mongo[c.VAULT_ITEMS].delete_many(owned)
    await mongo[c.PASSCODES].delete_one({"_id": passcode_id})

    remaining = await mongo[c.PASSCODES].count_documents({"user_id": claims.user_id})
    if remaining == 0:
        await mongo[c.USER_KEYS].update_one(
            {"_id": claims.user_id},
            {"$unset": {"salt_pw": "", "wrapped_umk": "", "kdf": ""}},
        )

    return {"deleted": True, "passcode_id": passcode_id, "items_removed": removed}


async def list_passcodes(*, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    docs = (
        await mongo[c.PASSCODES]
        .find(
            {"user_id": claims.user_id},
            {
                "_id": 1,
                "label": 1,
                "scope": 1,
                "salt_pc": 1,
                "kdf": 1,
                "key_source": 1,
                "wrapped_umk": 1,
                "crypto_version": 1,
                "created_at": 1,
                "last_used_at": 1,
            },
        )
        .to_list(length=c.LIST_LIMIT)
    )

    return {
        "items": [
            {
                "passcode_id": doc["_id"],
                "label": doc["label"],
                "scope": doc["scope"],
                "salt_pc": doc["salt_pc"],
                "kdf": doc.get("kdf", {}),
                "key_source": doc.get("key_source", "master"),
                "wrapped_umk": doc.get("wrapped_umk"),
                "crypto_version": doc.get("crypto_version", 1),
                "created_at": to_wire(doc.get("created_at")),
                "last_used_at": to_wire(doc.get("last_used_at")),
            }
            for doc in docs
        ]
    }


async def create_item(
    body: CreateItemRequest,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    storage: StoragePort,
    settings: Settings,
) -> dict[str, Any]:
    await _require_keys(claims.user_id, mongo)

    if body.visibility == "hidden" and not body.label_hash:
        raise api_error(ErrorCode.LABEL_REQUIRED, field="label_hash")

    limit = settings.limit_for(body.kind)
    if body.size_bytes > limit:
        raise api_error(
            ErrorCode.ITEM_TOO_LARGE,
            extra={"limit_bytes": limit, "kind": body.kind},
        )

    passcode = await mongo[c.PASSCODES].find_one(
        {"_id": body.passcode_id, "user_id": claims.user_id}, {"_id": 1}
    )
    if passcode is None:
        raise api_error(ErrorCode.PASSCODE_NOT_FOUND, field="passcode_id")

    used = await _used_bytes(claims.user_id, mongo)
    if used + body.size_bytes > settings.VAULT_QUOTA_BYTES:
        raise api_error(
            ErrorCode.QUOTA_EXCEEDED,
            extra={"used_bytes": used, "limit_bytes": settings.VAULT_QUOTA_BYTES},
        )

    count = await mongo[c.VAULT_ITEMS].count_documents(
        {"user_id": claims.user_id, "deleted_at": None}
    )
    if count >= settings.VAULT_MAX_ITEMS:
        raise api_error(ErrorCode.QUOTA_EXCEEDED, extra={"limit_items": settings.VAULT_MAX_ITEMS})

    item_id = new_id("vit")
    object_key = storage.key_for(owner_id=claims.user_id, item_id=item_id)
    now = utc_now()

    item = {
        "_id": item_id,
        "user_id": claims.user_id,
        "passcode_id": body.passcode_id,
        "kind": body.kind,
        "size_bytes": body.size_bytes,
        "chunk_count": body.chunk_count,
        "object_key": object_key,
        "encrypted_metadata": body.encrypted_metadata,
        "wrapped_dek": body.wrapped_dek,
        "salt_item": body.salt_item,
        "crypto_version": "story.dek.v1",
        "visibility": body.visibility,
        "label_hash": body.label_hash,
        "label_hint": body.label_hint,
        "thumb_encrypted": body.thumb_encrypted,
        "key_state": "active",
        "status": "pending",
        "scan_state": "pending",
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
    }

    try:
        await mongo[c.VAULT_ITEMS].insert_one(item)
    except DuplicateKeyError as exc:
        raise api_error(ErrorCode.LABEL_TAKEN, field="label_hash") from exc

    upload_url = await storage.presign_put(
        profile=c.VAULT_PROFILE,
        key=object_key,
        expires_in=settings.PRESIGN_UPLOAD_TTL_SECONDS,
    )

    return {"item": serialize_item(item), "upload_url": upload_url}


async def _used_bytes(user_id: str, mongo: AsyncIOMotorDatabase) -> int:
    cursor = mongo[c.VAULT_ITEMS].aggregate(
        [
            {"$match": {"user_id": user_id, "deleted_at": None}},
            {"$group": {"_id": None, "total": {"$sum": "$size_bytes"}}},
        ]
    )
    async for row in cursor:
        return int(row.get("total", 0))
    return 0


async def _owned_item(item_id: str, user_id: str, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    item = await mongo[c.VAULT_ITEMS].find_one(
        {"_id": item_id, "user_id": user_id, "deleted_at": None}
    )
    if item is None:
        raise api_error(ErrorCode.VAULT_ITEM_NOT_FOUND)
    return item


async def complete_item(
    item_id: str,
    body: CompleteItemRequest,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    storage: StoragePort,
) -> dict[str, Any]:
    item = await _owned_item(item_id, claims.user_id, mongo)

    actual = await storage.head(profile=c.VAULT_PROFILE, key=item["object_key"])
    if actual is None or actual != body.total_size or body.chunk_count != item["chunk_count"]:
        raise api_error(ErrorCode.UPLOAD_MISMATCH)

    now = utc_now()
    await mongo[c.VAULT_ITEMS].update_one(
        {"_id": item_id},
        {"$set": {"status": "ready", "scan_state": "unscannable", "updated_at": now}},
    )
    item.update({"status": "ready", "scan_state": "unscannable"})
    return {"item": serialize_item(item)}


async def list_items(
    *, claims, mongo: AsyncIOMotorDatabase, passcode_id: str | None = None
) -> dict[str, Any]:
    query = {"user_id": claims.user_id, "visibility": "normal", "deleted_at": None}
    if passcode_id is not None:
        query["passcode_id"] = passcode_id

    docs = (
        await mongo[c.VAULT_ITEMS]
        .find(query, c.LIST_PROJECTION)
        .sort("_id", -1)
        .limit(c.LIST_LIMIT)
        .to_list(length=c.LIST_LIMIT)
    )
    return {"items": [serialize_item(doc) for doc in docs]}


async def get_item(item_id: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    item = await _owned_item(item_id, claims.user_id, mongo)
    return {"item": serialize_item(item)}


async def search(label_hash: str, *, claims, mongo: AsyncIOMotorDatabase) -> dict[str, Any]:
    item = await mongo[c.VAULT_ITEMS].find_one(
        {"user_id": claims.user_id, "label_hash": label_hash, "deleted_at": None}
    )
    if item is None:
        raise api_error(ErrorCode.VAULT_ITEM_NOT_FOUND)
    return {"item": serialize_item(item)}


async def download_url(
    item_id: str,
    *,
    claims,
    mongo: AsyncIOMotorDatabase,
    storage: StoragePort,
    settings: Settings,
) -> dict[str, Any]:
    item = await _owned_item(item_id, claims.user_id, mongo)

    if item["status"] != "ready":
        raise api_error(ErrorCode.ITEM_NOT_READY)
    if item.get("key_state") == "orphaned":
        raise api_error(ErrorCode.ITEM_ORPHANED)

    url = await storage.presign_get(
        profile=c.VAULT_PROFILE,
        key=item["object_key"],
        expires_in=settings.PRESIGN_DOWNLOAD_TTL_SECONDS,
    )
    return {
        "download_url": url,
        "expires_in": settings.PRESIGN_DOWNLOAD_TTL_SECONDS,
        "chunk_count": item["chunk_count"],
    }


async def update_item(
    item_id: str, body: UpdateItemRequest, *, claims, mongo: AsyncIOMotorDatabase
) -> dict[str, Any]:
    item = await _owned_item(item_id, claims.user_id, mongo)

    update: dict[str, Any] = {"updated_at": utc_now()}
    if body.encrypted_metadata is not None:
        update["encrypted_metadata"] = body.encrypted_metadata

    if body.visibility is not None:
        if body.visibility == "hidden" and not (body.label_hash or item.get("label_hash")):
            raise api_error(ErrorCode.LABEL_REQUIRED, field="label_hash")
        update["visibility"] = body.visibility
        if body.visibility == "normal":
            update["label_hash"] = None

    if body.label_hash is not None:
        update["label_hash"] = body.label_hash

    try:
        await mongo[c.VAULT_ITEMS].update_one({"_id": item_id}, {"$set": update})
    except DuplicateKeyError as exc:
        raise api_error(ErrorCode.LABEL_TAKEN, field="label_hash") from exc

    item.update(update)
    return {"item": serialize_item(item)}


async def delete_item(
    item_id: str, *, claims, mongo: AsyncIOMotorDatabase, storage: StoragePort
) -> dict[str, Any]:
    item = await _owned_item(item_id, claims.user_id, mongo)

    await mongo[c.VAULT_ITEMS].update_one(
        {"_id": item_id},
        {"$set": {"deleted_at": utc_now(), "label_hash": None, "status": "deleting"}},
    )
    await storage.delete(profile=c.VAULT_PROFILE, key=item["object_key"])
    return {"deleted": True, "item_id": item_id}


async def overview(*, claims, mongo: AsyncIOMotorDatabase, settings: Settings) -> dict[str, Any]:
    visible = {"user_id": claims.user_id, "visibility": "normal", "deleted_at": None}

    used = 0
    cursor = mongo[c.VAULT_ITEMS].aggregate(
        [{"$match": visible}, {"$group": {"_id": None, "total": {"$sum": "$size_bytes"}}}]
    )
    async for row in cursor:
        used = int(row.get("total", 0))

    return {
        "item_count": await mongo[c.VAULT_ITEMS].count_documents(visible),
        "used_bytes": used,
        "limit_bytes": settings.VAULT_QUOTA_BYTES,
        "orphaned_count": await mongo[c.VAULT_ITEMS].count_documents(
            {"user_id": claims.user_id, "key_state": "orphaned", "deleted_at": None}
        ),
        "passcodes": (await list_passcodes(claims=claims, mongo=mongo))["items"],
    }
