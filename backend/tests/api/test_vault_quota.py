"""How much one person may keep, and what stops them keeping more.

The quota is the only thing standing between one account and the disk. It is
checked twice: once when space is reserved, and once when the bytes actually
land, because the two numbers come from different places and only the second
one is true.
"""

import base64

import pytest
import pytest_asyncio

from app.config import Settings
from app.ports.factory import build_storage

MB = 1024**2


@pytest_asyncio.fixture
async def mongo(app_instance):
    return app_instance.state.mongo_db


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


async def auth_headers(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


KEYS_BODY = {
    "salt_pw": b64(b"0123456789abcdef"),
    "wrapped_umk": b64(b"nonce12bytes" + b"ciphertext-of-the-user-master-key"),
    "kdf": {"algo": "argon2id", "memory_kib": 65536, "iterations": 3, "parallelism": 4},
}

PASSCODE_BODY = {
    "label": "Main vault",
    "scope": "vault",
    "passcode_hash": "$argon2id$v=19$m=65536,t=3,p=4$c2FsdA$aGFzaA",
    "salt_pc": b64(b"fedcba9876543210"),
    "kdf": {"algo": "argon2id", "memory_kib": 65536, "iterations": 3, "parallelism": 4},
    "escrow_payload": b64(b"escrowed-passcode-under-public-key"),
}


async def a_vault(client, payload):
    """A signed-in account with keys and one passcode, ready to hold things."""
    headers = await auth_headers(client, payload)
    await client.post("/v1/users/me/keys", json=KEYS_BODY, headers=headers)
    response = await client.post("/v1/vault/passcodes", json=PASSCODE_BODY, headers=headers)
    return headers, response.json()["data"]["passcode"]["passcode_id"]


def item_body(passcode_id, **overrides):
    return {
        "passcode_id": passcode_id,
        "kind": "image",
        "size_bytes": 2048,
        "chunk_count": 1,
        "encrypted_metadata": b64(b"encrypted-filename-and-mime"),
        "wrapped_dek": b64(b"nonce12bytes" + b"wrapped-data-key"),
        "salt_item": b64(b"0011223344556677"),
        "visibility": "normal",
        **overrides,
    }


async def fill_vault(mongo, payload, *, bytes_used, visibility="normal"):
    """Put a user's usage close to the ceiling without moving any real bytes."""
    me = await mongo["users"].find_one({"username_lower": payload["username"].lower()}, {"_id": 1})
    await mongo["vault_items"].insert_one(
        {
            "_id": f"vit_filler_{visibility}",
            "user_id": me["_id"],
            "passcode_id": "pc_filler",
            "kind": "image",
            "size_bytes": bytes_used,
            "chunk_count": 1,
            "object_key": "filler",
            "visibility": visibility,
            "status": "ready",
            "deleted_at": None,
        }
    )


def test_the_vault_starts_at_a_hundred_megabytes():
    assert Settings().VAULT_QUOTA_BYTES == 100 * MB


def test_the_quota_is_one_setting_away_from_being_larger():
    assert Settings(VAULT_QUOTA_BYTES=5 * 1024**3).VAULT_QUOTA_BYTES == 5 * 1024**3


async def test_a_reservation_past_the_quota_is_refused(client, signup_payload, mongo):
    headers, passcode_id = await a_vault(client, signup_payload)
    await fill_vault(mongo, signup_payload, bytes_used=100 * MB - 1024)

    response = await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)

    assert response.status_code == 400
    body = response.json()["data"]
    assert body["code"] == "QUOTA_EXCEEDED"
    assert body["limit_bytes"] == 100 * MB


async def test_a_hidden_item_spends_the_same_quota_as_any_other(client, signup_payload, mongo):
    """Hiding an item hides it from the listing, not from the accounting."""
    headers, passcode_id = await a_vault(client, signup_payload)
    await fill_vault(mongo, signup_payload, bytes_used=100 * MB - 1024, visibility="hidden")

    response = await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)

    assert response.status_code == 400
    assert response.json()["data"]["code"] == "QUOTA_EXCEEDED"


async def test_uploading_more_than_was_reserved_is_refused(client, signup_payload):
    """The reservation is the promise. Storage is the truth. They must agree.

    Without this, an account reserves two kilobytes, uploads twenty, and the
    quota keeps counting the two — which is the whole disk, one item at a time.
    """
    headers, passcode_id = await a_vault(client, signup_payload)
    created = (
        await client.post(
            "/v1/vault/items", json=item_body(passcode_id, size_bytes=2048), headers=headers
        )
    ).json()["data"]

    await client.put(created["upload_url"], content=b"x" * (20 * 1024))
    response = await client.post(
        f"/v1/vault/items/{created['item']['item_id']}/complete",
        json={"chunk_count": 1, "total_size": 20 * 1024},
        headers=headers,
    )

    assert response.status_code == 400
    assert response.json()["data"]["code"] == "UPLOAD_MISMATCH"


async def test_the_bytes_of_a_refused_upload_do_not_survive_it(client, signup_payload, mongo):
    """A refusal that leaves the bytes on disk is not a refusal."""
    headers, passcode_id = await a_vault(client, signup_payload)
    created = (
        await client.post(
            "/v1/vault/items", json=item_body(passcode_id, size_bytes=2048), headers=headers
        )
    ).json()["data"]
    item_id = created["item"]["item_id"]

    await client.put(created["upload_url"], content=b"x" * (20 * 1024))
    await client.post(
        f"/v1/vault/items/{item_id}/complete",
        json={"chunk_count": 1, "total_size": 20 * 1024},
        headers=headers,
    )

    item = await mongo["vault_items"].find_one({"_id": item_id})
    storage = build_storage(Settings())
    assert await storage.head(profile="vault", key=item["object_key"]) is None


async def test_an_upload_of_exactly_what_was_reserved_still_lands(client, signup_payload):
    headers, passcode_id = await a_vault(client, signup_payload)
    created = (
        await client.post(
            "/v1/vault/items", json=item_body(passcode_id, size_bytes=2048), headers=headers
        )
    ).json()["data"]

    await client.put(created["upload_url"], content=b"x" * 2048)
    response = await client.post(
        f"/v1/vault/items/{created['item']['item_id']}/complete",
        json={"chunk_count": 1, "total_size": 2048},
        headers=headers,
    )

    assert response.status_code == 202
    assert response.json()["data"]["item"]["status"] == "ready"


async def test_deleting_an_item_gives_the_space_back(client, signup_payload, mongo):
    headers, passcode_id = await a_vault(client, signup_payload)
    await fill_vault(mongo, signup_payload, bytes_used=100 * MB - 1024)

    refused = await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    await client.delete("/v1/vault/items/vit_filler_normal", headers=headers)
    allowed = await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)

    assert refused.status_code == 400
    assert allowed.status_code == 201


@pytest.mark.parametrize("field", ["used_bytes", "limit_bytes"])
async def test_the_overview_says_where_a_person_stands(client, signup_payload, field):
    headers, _ = await a_vault(client, signup_payload)

    data = (await client.get("/v1/vault/overview", headers=headers)).json()["data"]

    assert field in data
    assert data["limit_bytes"] == 100 * MB
