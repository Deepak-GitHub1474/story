import pytest

from tests.api.test_vault import (
    KEYS_BODY,
    PASSCODE_BODY,
    auth_headers,
    b64,
    init_keys,
    item_body,
)


@pytest.fixture
async def owner(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await init_keys(client, headers)
    return headers


async def make_vault(client, headers, label):
    body = {
        **PASSCODE_BODY,
        "label": label,
        "salt_pc": b64(label.encode().ljust(16, b"-")),
        "passcode_hash": f"verifier-for-{label}",
    }
    response = await client.post("/v1/vault/passcodes", json=body, headers=headers)
    return response.json()["data"]["passcode"]["passcode_id"]


async def make_item(client, headers, passcode_id):
    response = await client.post(
        "/v1/vault/items", json=item_body(passcode_id), headers=headers
    )
    return response.json()["data"]["item"]["item_id"]


async def test_you_can_keep_more_than_one_named_vault(client, owner):
    first = await make_vault(client, owner, "Papers")
    second = await make_vault(client, owner, "Pictures")

    listed = (await client.get("/v1/vault/passcodes", headers=owner)).json()["data"]["items"]
    labels = {row["label"]: row["passcode_id"] for row in listed}

    assert labels == {"Papers": first, "Pictures": second}


async def test_a_vault_only_lists_what_was_put_in_it(client, owner):
    papers = await make_vault(client, owner, "Papers")
    pictures = await make_vault(client, owner, "Pictures")
    in_papers = await make_item(client, owner, papers)
    await make_item(client, owner, pictures)

    response = await client.get(f"/v1/vault/items?passcode_id={papers}", headers=owner)

    assert response.status_code == 200
    items = response.json()["data"]["items"]
    assert [item["item_id"] for item in items] == [in_papers]


async def test_asking_for_no_vault_still_lists_everything(client, owner):
    papers = await make_vault(client, owner, "Papers")
    pictures = await make_vault(client, owner, "Pictures")
    await make_item(client, owner, papers)
    await make_item(client, owner, pictures)

    items = (await client.get("/v1/vault/items", headers=owner)).json()["data"]["items"]

    assert len(items) == 2


async def test_another_persons_vault_id_lists_nothing_of_yours(client, owner, signup_payload):
    mine = await make_vault(client, owner, "Papers")
    await make_item(client, owner, mine)

    stranger = await auth_headers(
        client,
        {"username": "vault_stranger", "password": "another-long-password", "tnc_accepted": True},
    )
    await client.post("/v1/users/me/keys", json=KEYS_BODY, headers=stranger)

    items = (
        await client.get(f"/v1/vault/items?passcode_id={mine}", headers=stranger)
    ).json()["data"]["items"]

    assert items == []


async def test_a_vault_is_identified_by_its_own_salt(client, owner):
    await make_vault(client, owner, "Papers")
    await make_vault(client, owner, "Pictures")

    listed = (await client.get("/v1/vault/passcodes", headers=owner)).json()["data"]["items"]
    salts = {row["label"]: row["salt_pc"] for row in listed}

    assert salts["Papers"] != salts["Pictures"]
    assert "passcode_hash" not in (
        await client.get("/v1/vault/passcodes", headers=owner)
    ).text


async def test_the_verifier_is_never_in_the_admin_view(client, owner, signup_payload):
    await make_vault(client, owner, "Papers")

    from app.api.endpoints.admin.vault_router import METADATA_ONLY

    assert "passcode_hash" not in METADATA_ONLY
    assert "salt_pc" not in METADATA_ONLY
    assert "escrow_payload" not in METADATA_ONLY
