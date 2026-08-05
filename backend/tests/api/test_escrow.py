import base64
import time

import pytest

from app.core.totp import code_at


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


async def enrolled_super_admin(client, app_instance, name):
    headers = await make_staff(client, app_instance, account(name), "super_admin")
    secret = (await client.post("/v1/auth/totp/setup", headers=headers)).json()["data"][
        "secret"
    ]
    await client.post(
        "/v1/auth/totp/confirm",
        json={"code": code_at(secret, int(time.time()))},
        headers=headers,
    )
    return headers, secret


async def make_staff(client, app_instance, payload, role):
    await auth_headers(client, payload)
    await app_instance.state.mongo_db["users"].update_one(
        {"username_lower": payload["username"]}, {"$set": {"role": role}}
    )
    signin = await client.post(
        "/v1/auth/signin",
        json={"username": payload["username"], "password": payload["password"]},
    )
    return {"authorization": f"Bearer {signin.json()['data']['tokens']['access_token']}"}


@pytest.fixture
def owner():
    return account("escrow_owner")


async def build_vault(client, headers):
    await client.post(
        "/v1/users/me/keys",
        json={
            "salt_pw": b64(b"0123456789abcdef"),
            "wrapped_umk": b64(b"nonce12bytes" + b"wrapped-master-key"),
            "kdf": {
                "algo": "argon2id",
                "memory_kib": 65536,
                "iterations": 3,
                "parallelism": 4,
            },
        },
        headers=headers,
    )
    await client.post(
        "/v1/vault/passcodes",
        json={
            "label": "Main vault",
            "scope": "vault",
            "passcode_hash": "$argon2id$v=19$m=65536,t=3,p=4$c2FsdA$aGFzaA",
            "salt_pc": b64(b"fedcba9876543210"),
            "kdf": {
                "algo": "argon2id",
                "memory_kib": 65536,
                "iterations": 3,
                "parallelism": 4,
            },
            "escrow_payload": b64(b"the-escrowed-passcode-material"),
        },
        headers=headers,
    )


async def test_a_moderator_cannot_reach_vault_escrow(client, owner, app_instance):
    staff = await make_staff(client, app_instance, account("esc_mod"), "moderator")
    response = await client.get(f"/v1/admin/vault/{owner['username']}/passcodes", headers=staff)
    assert response.status_code == 403


async def test_an_admin_cannot_reach_vault_escrow(client, owner, app_instance):
    staff = await make_staff(client, app_instance, account("esc_admin"), "admin")
    response = await client.get(f"/v1/admin/vault/{owner['username']}/passcodes", headers=staff)
    assert response.status_code == 403


async def test_a_super_admin_sees_passcode_metadata_only(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)

    staff = await make_staff(client, app_instance, account("esc_super"), "super_admin")
    response = await client.get(f"/v1/admin/vault/{owner['username']}/passcodes", headers=staff)

    assert response.status_code == 200
    body = response.text
    assert "escrow" not in body
    assert "passcode_hash" not in body
    assert "salt_pc" not in body

    items = response.json()["data"]["items"]
    assert items[0]["label"] == "Main vault"


async def test_the_escrow_listing_is_audited(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)

    staff = await make_staff(client, app_instance, account("esc_super2"), "super_admin")
    await client.get(f"/v1/admin/vault/{owner['username']}/passcodes", headers=staff)

    entries = (await client.get("/v1/admin/audit", headers=staff)).json()["data"]["items"]
    assert any(entry["action"] == "vault.passcodes_listed" for entry in entries)


async def test_there_is_no_endpoint_that_returns_vault_item_content(client, owner, app_instance):
    staff = await make_staff(client, app_instance, account("esc_super3"), "super_admin")

    for path in (
        f"/v1/admin/vault/{owner['username']}/items",
        f"/v1/admin/vault/{owner['username']}/keys",
        f"/v1/admin/vault/{owner['username']}/decrypt",
    ):
        response = await client.get(path, headers=staff)
        assert response.status_code == 404, path


async def test_releasing_escrow_needs_a_ticket(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)

    staff, secret = await enrolled_super_admin(client, app_instance, "esc_super4")
    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": "tkt_nonexistent",
            "justification": "x" * 60,
            "totp_code": code_at(secret, int(time.time())),
        },
        headers=staff,
    )
    assert response.status_code == 404
    assert response.json()["data"]["code"] == "TICKET_NOT_FOUND"


async def test_releasing_escrow_needs_a_long_justification(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket = (
        await client.post(
            "/v1/tickets",
            json={"type": "passcode_release", "reason": "I forgot my vault passcode."},
            headers=headers,
        )
    ).json()["data"]["ticket"]

    staff, secret = await enrolled_super_admin(client, app_instance, "esc_super5")
    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket["ticket_id"],
            "justification": "too short",
            "totp_code": code_at(secret, int(time.time())),
        },
        headers=staff,
    )
    assert response.status_code == 422


async def test_a_released_passcode_reaches_the_user_not_the_staff(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket = (
        await client.post(
            "/v1/tickets",
            json={"type": "passcode_release", "reason": "I forgot my vault passcode."},
            headers=headers,
        )
    ).json()["data"]["ticket"]

    staff, secret = await enrolled_super_admin(client, app_instance, "esc_super6")
    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket["ticket_id"],
            "justification": "Owner verified by email and answered every precondition.",
            "totp_code": code_at(secret, int(time.time())),
        },
        headers=staff,
    )

    assert response.status_code == 200
    assert "escrow" not in response.text
    assert response.json()["data"]["released"] is True

    mine = (await client.get("/v1/tickets", headers=headers)).json()["data"]["items"]
    assert mine[0]["state"] == "reveal_ready"


async def test_the_release_is_audited_and_visible_to_the_owner(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket = (
        await client.post(
            "/v1/tickets",
            json={"type": "passcode_release", "reason": "Locked out of my vault."},
            headers=headers,
        )
    ).json()["data"]["ticket"]

    staff, secret = await enrolled_super_admin(client, app_instance, "esc_super7")
    await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket["ticket_id"],
            "justification": "Owner verified by email and answered every precondition.",
            "totp_code": code_at(secret, int(time.time())),
        },
        headers=staff,
    )

    entries = (await client.get("/v1/admin/audit", headers=staff)).json()["data"]["items"]
    release = next(entry for entry in entries if entry["action"] == "passcode_release.approved")
    assert release["details"]["justification"]

    activity = (await client.get("/v1/security-activity", headers=headers)).json()["data"]
    assert any(item["action"] == "passcode_release.approved" for item in activity["items"])


async def test_a_user_can_open_and_see_their_own_ticket(client, owner):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)

    created = await client.post(
        "/v1/tickets",
        json={"type": "passcode_release", "reason": "I cannot remember my passcode."},
        headers=headers,
    )
    assert created.status_code == 201

    mine = (await client.get("/v1/tickets", headers=headers)).json()["data"]["items"]
    assert len(mine) == 1
    assert mine[0]["type"] == "passcode_release"


async def test_only_one_open_ticket_per_type(client, owner):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)

    body = {"type": "passcode_release", "reason": "Locked out of my vault entirely."}
    await client.post("/v1/tickets", json=body, headers=headers)
    second = await client.post("/v1/tickets", json=body, headers=headers)

    assert second.status_code == 409
    assert second.json()["data"]["code"] == "TICKET_ALREADY_OPEN"


async def test_another_user_cannot_see_your_ticket(client, owner):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    await client.post(
        "/v1/tickets",
        json={"type": "passcode_release", "reason": "Locked out of my vault."},
        headers=headers,
    )

    stranger = await auth_headers(client, account("esc_stranger"))
    items = (await client.get("/v1/tickets", headers=stranger)).json()["data"]["items"]
    assert items == []
