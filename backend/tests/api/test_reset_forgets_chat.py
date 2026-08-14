import base64

import pytest

from app.adapters.mail_console import outbox


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


KDF = {"algo": "argon2id", "memory_kib": 65536, "iterations": 3, "parallelism": 4}

KEYS_BODY = {
    "salt_pw": b64(b"0123456789abcdef"),
    "wrapped_umk": b64(b"nonce12bytes" + b"ciphertext-of-the-user-master-key"),
    "kdf": KDF,
}

PASSCODE_BODY = {
    "label": "Main vault",
    "scope": "vault",
    "passcode_hash": "$argon2id$v=19$m=65536,t=3,p=4$c2FsdA$aGFzaA",
    "salt_pc": b64(b"fedcba9876543210"),
    "kdf": KDF,
    "escrow_payload": b64(b"escrowed-passcode-under-public-key"),
}

NEW_PASSWORD = "a-brand-new-long-password"
FORGETFUL = "reset_ann"
FRIEND = "reset_ben"


@pytest.fixture(autouse=True)
def clear_outbox():
    outbox.clear()
    yield
    outbox.clear()


async def with_identity(client, name):
    headers = await auth_headers(client, account(name))
    await client.post(
        "/v1/chat/identity", json={"public_key": b64(bytes([1] * 32))}, headers=headers
    )
    await client.post(
        "/v1/chat/backup",
        json={
            "salt": b64(b"0123456789abcdef"),
            "wrapped_private_key": b64(b"nonce12bytes" + b"sealed-private-key"),
            "public_key": b64(bytes([1] * 32)),
            "kdf": KDF,
        },
        headers=headers,
    )
    return headers


async def talking_pair(client):
    forgetful = await with_identity(client, FORGETFUL)
    friend = await with_identity(client, FRIEND)

    await client.post(f"/v1/connections/{FRIEND}", headers=forgetful)
    await client.post(f"/v1/connections/{FORGETFUL}", headers=friend)

    started = await client.post(
        "/v1/chat/conversations",
        json={
            "username": FRIEND,
            "wrapped_cek_for_me": b64(b"nonce12bytes" + b"wrapped-for-ann"),
            "wrapped_cek_for_them": b64(b"nonce12bytes" + b"wrapped-for-ben"),
            "sender_public_key": b64(bytes([2] * 32)),
        },
        headers=forgetful,
    )
    conversation_id = started.json()["data"]["conversation"]["conversation_id"]

    await client.post(
        f"/v1/chat/conversations/{conversation_id}/messages",
        json={"ciphertext": b64(b"nonce12bytes" + b"something-said")},
        headers=forgetful,
    )
    await client.get(
        f"/v1/chat/conversations/{conversation_id}/messages", headers=friend
    )
    return forgetful, friend, conversation_id


async def reset_password(client, headers, username):
    await client.post(
        "/v1/users/me/email", json={"email": f"{username}@example.com"}, headers=headers
    )
    await client.post(
        "/v1/users/me/email/verify", json={"otp": outbox[-1]["otp"]}, headers=headers
    )
    outbox.clear()

    await client.post("/v1/auth/password-reset/request", json={"username": username})
    verify = await client.post(
        "/v1/auth/password-reset/verify",
        json={"username": username, "otp": outbox[-1]["otp"]},
    )
    return await client.post(
        "/v1/auth/password-reset/complete",
        json={
            "reset_token": verify.json()["data"]["reset_token"],
            "new_password": NEW_PASSWORD,
            "acknowledged_vault_loss": True,
        },
    )


async def signed_in_again(client, username):
    signin = await client.post(
        "/v1/auth/signin", json={"username": username, "password": NEW_PASSWORD}
    )
    return {"authorization": f"Bearer {signin.json()['data']['tokens']['access_token']}"}


async def id_of(app_instance, username):
    user = await app_instance.state.mongo_db["users"].find_one({"username": username})
    return user["_id"]


async def test_a_reset_takes_away_the_keys_that_opened_my_chats(client, app_instance):
    forgetful, _, _ = await talking_pair(client)

    await reset_password(client, forgetful, FORGETFUL)

    mine = await id_of(app_instance, FORGETFUL)
    left = await app_instance.state.mongo_db["chat_conversation_keys"].count_documents(
        {"user_id": mine}
    )
    assert left == 0


async def test_a_reset_takes_away_the_backup_i_can_no_longer_open(client, app_instance):
    forgetful, _, _ = await talking_pair(client)

    await reset_password(client, forgetful, FORGETFUL)

    mine = await id_of(app_instance, FORGETFUL)
    assert await app_instance.state.mongo_db["chat_identities"].find_one({"_id": mine}) is None


async def test_my_chats_are_gone_from_my_list_after_a_reset(client):
    forgetful, _, _ = await talking_pair(client)

    await reset_password(client, forgetful, FORGETFUL)
    fresh = await signed_in_again(client, FORGETFUL)

    listed = await client.get("/v1/chat/conversations", headers=fresh)
    assert listed.json()["data"]["items"] == []


async def test_the_other_person_keeps_their_chat(client, app_instance):
    forgetful, friend, conversation_id = await talking_pair(client)

    await reset_password(client, forgetful, FORGETFUL)

    listed = await client.get("/v1/chat/conversations", headers=friend)
    rooms = [room["conversation_id"] for room in listed.json()["data"]["items"]]
    assert conversation_id in rooms

    theirs = await id_of(app_instance, FRIEND)
    assert await app_instance.state.mongo_db["chat_conversation_keys"].find_one(
        {"user_id": theirs}
    ) is not None


async def test_the_other_person_can_still_read_what_was_said(client):
    forgetful, friend, conversation_id = await talking_pair(client)

    await reset_password(client, forgetful, FORGETFUL)

    messages = await client.get(
        f"/v1/chat/conversations/{conversation_id}/messages", headers=friend
    )
    assert len(messages.json()["data"]["items"]) == 1


async def test_the_vault_is_left_exactly_as_it_was(client, app_instance):
    forgetful = await with_identity(client, FORGETFUL)
    await client.post("/v1/users/me/keys", json=KEYS_BODY, headers=forgetful)
    await client.post("/v1/vault/passcodes", json=PASSCODE_BODY, headers=forgetful)

    await reset_password(client, forgetful, FORGETFUL)

    mine = await id_of(app_instance, FORGETFUL)
    keys = await app_instance.state.mongo_db["user_keys"].find_one({"_id": mine})
    assert keys["wrapped_umk"] == KEYS_BODY["wrapped_umk"]
    assert keys["salt_pw"] == KEYS_BODY["salt_pw"]
    assert await app_instance.state.mongo_db["user_passcodes"].find_one({"user_id": mine})


async def test_a_reset_leaves_no_unreadable_leftovers_of_mine(client, app_instance):
    forgetful, _, _ = await talking_pair(client)

    await reset_password(client, forgetful, FORGETFUL)

    mine = await id_of(app_instance, FORGETFUL)
    db = app_instance.state.mongo_db
    assert await db["chat_conversation_keys"].count_documents({"user_id": mine}) == 0
    assert await db["chat_reads"].count_documents({"user_id": mine}) == 0
    assert await db["chat_identities"].count_documents({"_id": mine}) == 0
