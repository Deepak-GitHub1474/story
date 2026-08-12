from tests.api.test_vault import (
    PASSCODE_BODY,
    account,
    auth_headers,
    init_keys,
    item_body,
    make_passcode,
)

USER_KEYS = "user_keys"


async def a_vault(client, name):
    headers = await auth_headers(client, account(name))
    await init_keys(client, headers)
    return headers, await make_passcode(client, headers)


async def test_a_vault_can_be_renamed(client):
    headers, passcode_id = await a_vault(client, "vault_rename_a")

    response = await client.patch(
        f"/v1/vault/passcodes/{passcode_id}",
        json={"label": "Paperwork"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["passcode"]["label"] == "Paperwork"

    listed = (await client.get("/v1/vault/passcodes", headers=headers)).json()["data"]
    assert [entry["label"] for entry in listed["items"]] == ["Paperwork"]


async def test_a_name_already_in_use_is_refused(client):
    headers, first = await a_vault(client, "vault_rename_b")
    await client.post(
        "/v1/vault/passcodes",
        json={**PASSCODE_BODY, "label": "Second vault"},
        headers=headers,
    )

    response = await client.patch(
        f"/v1/vault/passcodes/{first}",
        json={"label": "Second vault"},
        headers=headers,
    )

    assert response.status_code == 409
    assert response.json()["data"]["code"] == "PASSCODE_LABEL_TAKEN"


async def test_two_people_may_use_the_same_name(client):
    mine, my_vault = await a_vault(client, "vault_rename_c")
    theirs, their_vault = await a_vault(client, "vault_rename_d")

    assert (
        await client.patch(
            f"/v1/vault/passcodes/{my_vault}", json={"label": "Home"}, headers=mine
        )
    ).status_code == 200
    assert (
        await client.patch(
            f"/v1/vault/passcodes/{their_vault}", json={"label": "Home"}, headers=theirs
        )
    ).status_code == 200


async def test_someone_else_cannot_rename_your_vault(client):
    _, mine = await a_vault(client, "vault_rename_e")
    theirs, _ = await a_vault(client, "vault_rename_f")

    response = await client.patch(
        f"/v1/vault/passcodes/{mine}", json={"label": "Taken over"}, headers=theirs
    )

    assert response.status_code == 404


async def test_deleting_a_vault_takes_its_files_with_it(client):
    headers, passcode_id = await a_vault(client, "vault_delete_a")
    await client.post("/v1/vault/items", json=item_body(passcode_id), headers=headers)

    response = await client.delete(f"/v1/vault/passcodes/{passcode_id}", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["items_removed"] == 1

    listed = (await client.get("/v1/vault/items", headers=headers)).json()["data"]
    assert listed["items"] == []


async def test_the_last_vault_leaving_clears_the_keys_for_a_fresh_start(client, app_instance):
    headers, passcode_id = await a_vault(client, "vault_delete_b")

    await client.delete(f"/v1/vault/passcodes/{passcode_id}", headers=headers)

    record = await app_instance.state.mongo_db[USER_KEYS].find_one({}, {"wrapped_umk": 1})
    assert record is None or record.get("wrapped_umk") is None
    assert (await init_keys(client, headers)).status_code == 201


async def test_one_vault_leaving_keeps_the_keys_for_the_others(client, app_instance):
    headers, first = await a_vault(client, "vault_delete_c")
    second = (
        await client.post(
            "/v1/vault/passcodes",
            json={**PASSCODE_BODY, "label": "Second vault"},
            headers=headers,
        )
    ).json()["data"]["passcode"]["passcode_id"]

    await client.delete(f"/v1/vault/passcodes/{first}", headers=headers)

    record = await app_instance.state.mongo_db[USER_KEYS].find_one({}, {"wrapped_umk": 1})
    assert record["wrapped_umk"] is not None

    remaining = (await client.get("/v1/vault/passcodes", headers=headers)).json()["data"]
    assert [entry["passcode_id"] for entry in remaining["items"]] == [second]


async def test_someone_else_cannot_delete_your_vault(client):
    mine, my_vault = await a_vault(client, "vault_delete_d")
    theirs, _ = await a_vault(client, "vault_delete_e")

    response = await client.delete(f"/v1/vault/passcodes/{my_vault}", headers=theirs)

    assert response.status_code == 404

    still = (await client.get("/v1/vault/passcodes", headers=mine)).json()["data"]
    assert [entry["passcode_id"] for entry in still["items"]] == [my_vault]


async def test_a_vault_that_is_not_there_is_a_clean_404(client):
    headers, _ = await a_vault(client, "vault_delete_f")

    response = await client.delete("/v1/vault/passcodes/pcd_nothing", headers=headers)

    assert response.status_code == 404
    assert response.json()["data"]["code"] == "PASSCODE_NOT_FOUND"
