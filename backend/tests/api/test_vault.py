import base64

import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


@pytest.fixture
def other():
    return account("vault_other")


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


async def init_keys(client, headers):
    return await client.post("/v1/users/me/keys", json=KEYS_BODY, headers=headers)


async def make_passcode(client, headers):
    response = await client.post("/v1/vault/passcodes", json=PASSCODE_BODY, headers=headers)
    return response.json()["data"]["passcode"]["passcode_id"]


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


async def test_keys_can_be_initialised_once(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    assert (await init_keys(client, headers)).status_code == 201

    second = await init_keys(client, headers)
    assert second.status_code == 409
    assert second.json()["data"]["code"] == "KEYS_ALREADY_INITIALIZED"


async def test_keys_are_returned_for_unwrapping_at_signin(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)

    data = (await client.get("/v1/users/me/keys", headers=headers)).json()["data"]
    assert data["salt_pw"] == KEYS_BODY["salt_pw"]
    assert data["wrapped_umk"] == KEYS_BODY["wrapped_umk"]
    assert data["kdf"]["algo"] == "argon2id"


async def test_the_vault_refuses_to_work_before_keys_exist(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post("/v1/vault/passcodes", json=PASSCODE_BODY, headers=headers)
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "KEYS_NOT_INITIALIZED"


async def test_a_passcode_never_returns_its_value_or_hash(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    await make_passcode(client, headers)

    response = await client.get("/v1/vault/passcodes", headers=headers)
    assert "passcode_hash" not in response.text
    assert "escrow" not in response.text
    assert response.json()["data"]["items"][0]["label"] == "Main vault"


async def test_creating_an_item_returns_an_upload_url(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    response = await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["item"]["status"] == "pending"
    assert data["upload_url"]


async def test_the_object_key_carries_no_filename(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    item = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]["item"]

    document = await app_instance.state.mongo_db["vault_items"].find_one({"_id": item["item_id"]})
    assert document["object_key"].endswith(item["item_id"])
    assert "." not in document["object_key"].rsplit("/", 1)[-1]


async def test_the_server_stores_no_plaintext_metadata(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)

    document = await app_instance.state.mongo_db["vault_items"].find_one({})
    assert "filename" not in document
    assert "mime" not in document
    assert document["encrypted_metadata"]


async def test_an_item_becomes_ready_once_the_object_exists(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    created = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]
    item_id = created["item"]["item_id"]

    await client.put(created["upload_url"], content=b"x" * 2048)
    response = await client.post(
        f"/v1/vault/items/{item_id}/complete",
        json={"chunk_count": 1, "total_size": 2048},
        headers=headers,
    )
    assert response.status_code == 202
    assert response.json()["data"]["item"]["status"] == "ready"


async def test_completing_with_a_mismatched_size_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    created = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]

    await client.put(created["upload_url"], content=b"x" * 10)
    response = await client.post(
        f"/v1/vault/items/{created['item']['item_id']}/complete",
        json={"chunk_count": 1, "total_size": 2048},
        headers=headers,
    )
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "UPLOAD_MISMATCH"


async def test_normal_items_are_listed(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)

    items = (await client.get("/v1/vault/items", headers=headers)).json()["data"]["items"]
    assert len(items) == 1


async def test_a_hidden_item_is_never_listed(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    await client.post(
        "/v1/vault/items",
        json=item_body(passcode_id, visibility="hidden", label_hash="a" * 64),
        headers=headers,
    )

    response = await client.get("/v1/vault/items", headers=headers)
    assert response.json()["data"]["items"] == []


async def test_a_hidden_item_needs_a_label(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    response = await client.post(
        "/v1/vault/items",
        json=item_body(passcode_id, visibility="hidden"),
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "LABEL_REQUIRED"


async def test_a_hidden_item_is_found_by_its_exact_label(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    created = (
        await client.post(
            "/v1/vault/items",
            json=item_body(passcode_id, visibility="hidden", label_hash="b" * 64),
            headers=headers,
        )
    ).json()["data"]["item"]

    response = await client.post("/v1/vault/search", json={"label_hash": "b" * 64}, headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["item"]["item_id"] == created["item_id"]


async def test_a_missing_label_is_a_generic_404(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)

    response = await client.post("/v1/vault/search", json={"label_hash": "c" * 64}, headers=headers)
    assert response.status_code == 404
    assert response.json()["data"]["code"] == "VAULT_ITEM_NOT_FOUND"


async def test_hidden_items_are_excluded_from_the_overview(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    await client.post(
        "/v1/vault/items",
        json=item_body(passcode_id, visibility="hidden", label_hash="d" * 64),
        headers=headers,
    )

    overview = (await client.get("/v1/vault/overview", headers=headers)).json()["data"]
    assert overview["item_count"] == 1
    assert overview["used_bytes"] == 2048


async def test_another_user_cannot_read_your_item(client, signup_payload, other):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    item = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]["item"]

    stranger = await auth_headers(client, other)
    response = await client.get(f"/v1/vault/items/{item['item_id']}", headers=stranger)
    assert response.status_code == 404


async def test_another_user_cannot_download_your_item(client, signup_payload, other):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    item = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]["item"]

    stranger = await auth_headers(client, other)
    response = await client.get(f"/v1/vault/items/{item['item_id']}/download", headers=stranger)
    assert response.status_code == 404


async def test_a_hidden_item_of_another_user_is_not_found_by_label(client, signup_payload, other):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    await client.post(
        "/v1/vault/items",
        json=item_body(passcode_id, visibility="hidden", label_hash="e" * 64),
        headers=headers,
    )

    stranger = await auth_headers(client, other)
    await init_keys(client, stranger)
    response = await client.post(
        "/v1/vault/search", json={"label_hash": "e" * 64}, headers=stranger
    )
    assert response.status_code == 404


async def test_the_download_url_is_only_issued_when_ready(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    item = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]["item"]

    response = await client.get(f"/v1/vault/items/{item['item_id']}/download", headers=headers)
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "ITEM_NOT_READY"


async def test_an_oversized_item_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    response = await client.post(
        "/v1/vault/items",
        json=item_body(passcode_id, size_bytes=600 * 1024 * 1024),
        headers=headers,
    )
    assert response.status_code == 413
    assert response.json()["data"]["code"] == "ITEM_TOO_LARGE"


async def test_deleting_an_item_removes_it_from_the_list(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    item = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]["item"]

    await client.delete(f"/v1/vault/items/{item['item_id']}", headers=headers)
    items = (await client.get("/v1/vault/items", headers=headers)).json()["data"]["items"]
    assert items == []


async def test_the_item_returns_its_key_material_for_client_decryption(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)
    created = (
        await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)
    ).json()["data"]["item"]

    item = (await client.get(f"/v1/vault/items/{created['item_id']}", headers=headers)).json()[
        "data"
    ]["item"]

    assert item["wrapped_dek"] == item_body(passcode_id)["wrapped_dek"]
    assert item["salt_item"] == item_body(passcode_id)["salt_item"]
    assert item["encrypted_metadata"]


async def test_a_duplicate_label_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    body = item_body(passcode_id, visibility="hidden", label_hash="f" * 64)
    await client.post("/v1/vault/items", json=body, headers=headers)
    response = await client.post("/v1/vault/items", json=body, headers=headers)

    assert response.status_code == 409
    assert response.json()["data"]["code"] == "LABEL_TAKEN"


async def test_the_vault_takes_only_images_video_and_pdf(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    passcode_id = await make_passcode(client, headers)

    for kind in ("image", "video", "pdf"):
        response = await client.post(
            "/v1/vault/items", json=item_body(passcode_id, kind=kind), headers=headers
        )
        assert response.status_code == 201, kind

    for kind in ("document", "audio", "other", "spreadsheet"):
        response = await client.post(
            "/v1/vault/items", json=item_body(passcode_id, kind=kind), headers=headers
        )
        assert response.status_code == 422, kind
