import base64


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


def backup_body(**overrides):
    return {
        "salt": b64(b"0123456789abcdef"),
        "wrapped_private_key": b64(b"nonce12bytes" + b"the-wrapped-identity-key"),
        "public_key": b64(bytes([7] * 32)),
        "kdf": {
            "algo": "argon2id",
            "memory_kib": 65536,
            "iterations": 3,
            "parallelism": 4,
        },
        **overrides,
    }


async def test_a_backup_can_be_stored_and_read_back(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    stored = await client.post("/v1/chat/backup", json=backup_body(), headers=headers)
    assert stored.status_code == 200

    mine = await client.get("/v1/chat/backup", headers=headers)
    assert mine.status_code == 200
    assert mine.json()["data"]["wrapped_private_key"] == backup_body()["wrapped_private_key"]
    assert mine.json()["data"]["salt"] == backup_body()["salt"]


async def test_storing_a_backup_publishes_the_public_key_too(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post("/v1/chat/backup", json=backup_body(), headers=headers)

    identity = await client.get("/v1/chat/identity", headers=headers)

    assert identity.json()["data"]["public_key"] == backup_body()["public_key"]


async def test_a_second_device_reads_the_same_backup(client, signup_payload):
    first = await auth_headers(client, signup_payload)
    await client.post("/v1/chat/backup", json=backup_body(), headers=first)

    second = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    token = second.json()["data"]["tokens"]["access_token"]

    mine = await client.get(
        "/v1/chat/backup", headers={"authorization": f"Bearer {token}"}
    )

    assert mine.json()["data"]["wrapped_private_key"] == backup_body()["wrapped_private_key"]


async def test_nobody_else_can_read_your_backup(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    await client.post("/v1/chat/backup", json=backup_body(), headers=mine)

    stranger = await auth_headers(client, account("backup_snoop"))
    theirs = await client.get("/v1/chat/backup", headers=stranger)

    assert theirs.status_code == 404


async def test_there_is_no_endpoint_that_lists_backups(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    for path in ("/v1/chat/backups", "/v1/admin/chat/backups"):
        assert (await client.get(path, headers=headers)).status_code in (403, 404)


async def test_a_backup_replaces_the_previous_one(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post("/v1/chat/backup", json=backup_body(), headers=headers)

    await client.post(
        "/v1/chat/backup",
        json=backup_body(wrapped_private_key=b64(b"nonce12bytes" + b"a-newer-key")),
        headers=headers,
    )

    mine = (await client.get("/v1/chat/backup", headers=headers)).json()["data"]
    assert mine["wrapped_private_key"] == b64(b"nonce12bytes" + b"a-newer-key")


async def test_no_backup_yet_is_a_clean_404(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.get("/v1/chat/backup", headers=headers)

    assert response.status_code == 404
    assert response.json()["data"]["code"] == "CHAT_NO_BACKUP"


async def test_the_server_never_sees_the_private_key_in_the_clear(
    client, signup_payload, app_instance
):
    headers = await auth_headers(client, signup_payload)
    await client.post("/v1/chat/backup", json=backup_body(), headers=headers)

    stored = await app_instance.state.mongo_db["chat_identities"].find_one({})

    assert "private_key" not in stored
    assert stored["backup"]["wrapped_private_key"] == backup_body()["wrapped_private_key"]
