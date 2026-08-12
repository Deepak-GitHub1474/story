from tests.api.test_vault import (
    KEYS_BODY,
    PASSCODE_BODY,
    account,
    auth_headers,
    b64,
    init_keys,
)

OWN_KEY = {
    "key_source": "own",
    "wrapped_umk": b64(b"nonce12bytes" + b"a-key-only-this-vault-can-open"),
}


async def signed_in(client, name):
    headers = await auth_headers(client, account(name))
    return headers


async def make_vault(client, headers, label, **overrides):
    return await client.post(
        "/v1/vault/passcodes",
        json={**PASSCODE_BODY, "label": label, **overrides},
        headers=headers,
    )


async def test_a_vault_on_the_main_passcode_needs_no_key_of_its_own(client):
    headers = await signed_in(client, "vkeys_a")
    await init_keys(client, headers)

    vault = (await make_vault(client, headers, "Main vault")).json()["data"]["passcode"]

    assert vault["key_source"] == "master"
    assert vault["wrapped_umk"] is None


async def test_a_vault_with_its_own_passcode_carries_its_own_key(client):
    headers = await signed_in(client, "vkeys_b")
    await init_keys(client, headers)

    vault = (
        await make_vault(client, headers, "Private things", **OWN_KEY)
    ).json()["data"]["passcode"]

    assert vault["key_source"] == "own"
    assert vault["wrapped_umk"] == OWN_KEY["wrapped_umk"]
    assert vault["crypto_version"] == 2


async def test_a_vault_with_its_own_key_can_be_made_before_any_main_passcode(client):
    headers = await signed_in(client, "vkeys_c")

    response = await make_vault(client, headers, "First one", **OWN_KEY)

    assert response.status_code == 201, "being locked out must not block a new vault"
    assert response.json()["data"]["passcode"]["key_source"] == "own"


async def test_a_vault_claiming_its_own_key_must_bring_one(client):
    headers = await signed_in(client, "vkeys_d")

    response = await make_vault(client, headers, "Empty promise", key_source="own")

    assert response.status_code == 422


async def test_the_list_carries_what_unlocking_needs(client):
    headers = await signed_in(client, "vkeys_e")
    await init_keys(client, headers)
    await make_vault(client, headers, "Main vault")
    await make_vault(client, headers, "Separate", **OWN_KEY)

    items = (await client.get("/v1/vault/passcodes", headers=headers)).json()["data"]["items"]
    by_label = {entry["label"]: entry for entry in items}

    assert by_label["Main vault"]["key_source"] == "master"
    assert by_label["Separate"]["wrapped_umk"] == OWN_KEY["wrapped_umk"]
    assert by_label["Separate"]["salt_pc"] == PASSCODE_BODY["salt_pc"]


async def test_the_main_passcode_can_be_changed_without_touching_files(client):
    headers = await signed_in(client, "vkeys_f")
    await init_keys(client, headers)

    fresh = {
        "salt_pw": b64(b"a-brand-new-salt"),
        "wrapped_umk": b64(b"nonce12bytes" + b"the-same-umk-under-a-new-passcode"),
        "kdf": KEYS_BODY["kdf"],
    }
    response = await client.put("/v1/users/me/keys", json=fresh, headers=headers)

    assert response.status_code == 200

    keys = (await client.get("/v1/users/me/keys", headers=headers)).json()["data"]
    assert keys["salt_pw"] == fresh["salt_pw"]
    assert keys["wrapped_umk"] == fresh["wrapped_umk"]


async def test_one_vault_passcode_changes_alone(client):
    headers = await signed_in(client, "vkeys_g")
    await init_keys(client, headers)
    vault_id = (
        await make_vault(client, headers, "Separate", **OWN_KEY)
    ).json()["data"]["passcode"]["passcode_id"]

    fresh = {
        "salt_pc": b64(b"another-new-salt"),
        "wrapped_umk": b64(b"nonce12bytes" + b"same-vault-key-new-passcode"),
        "kdf": PASSCODE_BODY["kdf"],
    }
    response = await client.put(
        f"/v1/vault/passcodes/{vault_id}/key", json=fresh, headers=headers
    )

    assert response.status_code == 200

    items = (await client.get("/v1/vault/passcodes", headers=headers)).json()["data"]["items"]
    changed = next(entry for entry in items if entry["passcode_id"] == vault_id)
    assert changed["wrapped_umk"] == fresh["wrapped_umk"]


async def test_a_vault_on_the_main_passcode_refuses_its_own_key_change(client):
    headers = await signed_in(client, "vkeys_h")
    await init_keys(client, headers)
    vault_id = (
        await make_vault(client, headers, "Main vault")
    ).json()["data"]["passcode"]["passcode_id"]

    response = await client.put(
        f"/v1/vault/passcodes/{vault_id}/key",
        json={
            "salt_pc": b64(b"another-new-salt"),
            "wrapped_umk": b64(b"nonce12bytes" + b"should-not-be-accepted"),
            "kdf": PASSCODE_BODY["kdf"],
        },
        headers=headers,
    )

    assert response.status_code == 400
    assert response.json()["data"]["code"] == "VAULT_USES_MASTER_KEY"


async def test_someone_else_cannot_rekey_your_vault(client):
    mine = await signed_in(client, "vkeys_i")
    await init_keys(client, mine)
    vault_id = (
        await make_vault(client, mine, "Separate", **OWN_KEY)
    ).json()["data"]["passcode"]["passcode_id"]

    theirs = await signed_in(client, "vkeys_j")
    response = await client.put(
        f"/v1/vault/passcodes/{vault_id}/key",
        json={
            "salt_pc": b64(b"attacker-chosen!"),
            "wrapped_umk": b64(b"nonce12bytes" + b"a-key-the-attacker-knows"),
            "kdf": PASSCODE_BODY["kdf"],
        },
        headers=theirs,
    )

    assert response.status_code == 404
