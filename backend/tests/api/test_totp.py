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


async def enrol(client, headers):
    secret = (await client.post("/v1/auth/totp/setup", headers=headers)).json()["data"][
        "secret"
    ]
    confirmed = await client.post(
        "/v1/auth/totp/confirm",
        json={"code": code_at(secret, int(time.time()))},
        headers=headers,
    )
    return secret, confirmed


@pytest.fixture
def owner():
    return account("totp_owner")


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


async def owner_with_ticket(client, name):
    headers = await auth_headers(client, account(name))
    await build_vault(client, headers)
    return name, await open_ticket(client, headers)


async def open_ticket(client, headers):
    return (
        await client.post(
            "/v1/tickets",
            json={"type": "passcode_release", "reason": "I forgot my vault passcode."},
            headers=headers,
        )
    ).json()["data"]["ticket"]["ticket_id"]


async def test_setup_hands_back_a_secret_and_a_provisioning_uri(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_a"), "super_admin")

    response = await client.post("/v1/auth/totp/setup", headers=staff)

    assert response.status_code == 200
    data = response.json()["data"]
    assert len(base64.b32decode(data["secret"])) == 20
    assert data["uri"].startswith("otpauth://totp/")


async def test_setup_is_not_open_to_ordinary_users(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post("/v1/auth/totp/setup", headers=headers)
    assert response.status_code == 403


async def test_a_wrong_first_code_does_not_activate(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_b"), "super_admin")
    await client.post("/v1/auth/totp/setup", headers=staff)

    response = await client.post(
        "/v1/auth/totp/confirm", json={"code": "000000"}, headers=staff
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "TOTP_INVALID"

    status_response = await client.get("/v1/auth/totp", headers=staff)
    assert status_response.json()["data"]["enabled"] is False


async def test_a_correct_first_code_activates_and_returns_backup_codes(
    client, app_instance
):
    staff = await make_staff(client, app_instance, account("totp_c"), "super_admin")
    _, confirmed = await enrol(client, staff)

    assert confirmed.status_code == 200
    codes = confirmed.json()["data"]["backup_codes"]
    assert len(codes) == 8

    status_response = await client.get("/v1/auth/totp", headers=staff)
    assert status_response.json()["data"]["enabled"] is True


async def test_the_secret_is_never_returned_again_after_activation(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_d"), "super_admin")
    await enrol(client, staff)

    status_response = await client.get("/v1/auth/totp", headers=staff)
    assert "secret" not in status_response.text
    assert "backup_codes" not in status_response.text


async def test_setting_up_twice_is_refused_once_enabled(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_e"), "super_admin")
    await enrol(client, staff)

    response = await client.post("/v1/auth/totp/setup", headers=staff)
    assert response.status_code == 409
    assert response.json()["data"]["code"] == "TOTP_ALREADY_ENABLED"


async def test_a_release_without_a_code_is_refused(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket_id = await open_ticket(client, headers)

    staff = await make_staff(client, app_instance, account("totp_f"), "super_admin")
    await enrol(client, staff)

    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket_id,
            "justification": "Owner verified by email and answered every precondition.",
        },
        headers=staff,
    )

    assert response.status_code == 422


async def test_a_release_with_a_wrong_code_is_refused(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket_id = await open_ticket(client, headers)

    staff = await make_staff(client, app_instance, account("totp_g"), "super_admin")
    await enrol(client, staff)

    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket_id,
            "justification": "Owner verified by email and answered every precondition.",
            "totp_code": "000000",
        },
        headers=staff,
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "TOTP_INVALID"


async def test_a_release_with_the_right_code_goes_through(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket_id = await open_ticket(client, headers)

    staff = await make_staff(client, app_instance, account("totp_h"), "super_admin")
    secret, _ = await enrol(client, staff)

    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket_id,
            "justification": "Owner verified by email and answered every precondition.",
            "totp_code": code_at(secret, int(time.time())),
        },
        headers=staff,
    )

    assert response.status_code == 200
    assert response.json()["data"]["released"] is True


async def test_the_same_code_cannot_be_replayed(client, app_instance):
    first_owner, first_ticket = await owner_with_ticket(client, "replay_one")
    second_owner, second_ticket = await owner_with_ticket(client, "replay_two")

    staff = await make_staff(client, app_instance, account("totp_i"), "super_admin")
    secret, _ = await enrol(client, staff)
    code = code_at(secret, int(time.time()))

    justification = "Owner verified by email and answered every precondition."
    first = await client.post(
        f"/v1/admin/vault/{first_owner}/release",
        json={
            "ticket_id": first_ticket,
            "justification": justification,
            "totp_code": code,
        },
        headers=staff,
    )
    assert first.status_code == 200

    second = await client.post(
        f"/v1/admin/vault/{second_owner}/release",
        json={
            "ticket_id": second_ticket,
            "justification": justification,
            "totp_code": code,
        },
        headers=staff,
    )

    assert second.status_code == 403
    assert second.json()["data"]["code"] == "TOTP_REUSED"


async def test_a_release_is_refused_when_the_staff_never_enrolled(
    client, owner, app_instance
):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)
    ticket_id = await open_ticket(client, headers)

    staff = await make_staff(client, app_instance, account("totp_j"), "super_admin")

    response = await client.post(
        f"/v1/admin/vault/{owner['username']}/release",
        json={
            "ticket_id": ticket_id,
            "justification": "Owner verified by email and answered every precondition.",
            "totp_code": "123456",
        },
        headers=staff,
    )

    assert response.status_code == 403
    assert response.json()["data"]["code"] == "TOTP_REQUIRED"


async def test_a_backup_code_works_once_and_then_never_again(client, app_instance):
    first_owner, first_ticket = await owner_with_ticket(client, "backup_one")
    second_owner, second_ticket = await owner_with_ticket(client, "backup_two")

    staff = await make_staff(client, app_instance, account("totp_k"), "super_admin")
    _, confirmed = await enrol(client, staff)
    backup = confirmed.json()["data"]["backup_codes"][0]

    justification = "Owner verified by email and answered every precondition."
    first = await client.post(
        f"/v1/admin/vault/{first_owner}/release",
        json={
            "ticket_id": first_ticket,
            "justification": justification,
            "totp_code": backup,
        },
        headers=staff,
    )
    assert first.status_code == 200

    second = await client.post(
        f"/v1/admin/vault/{second_owner}/release",
        json={
            "ticket_id": second_ticket,
            "justification": justification,
            "totp_code": backup,
        },
        headers=staff,
    )
    assert second.status_code == 403
    assert second.json()["data"]["code"] == "TOTP_INVALID"


async def test_listing_passcode_names_does_not_need_a_code(client, owner, app_instance):
    headers = await auth_headers(client, owner)
    await build_vault(client, headers)

    staff = await make_staff(client, app_instance, account("totp_l"), "super_admin")
    response = await client.get(
        f"/v1/admin/vault/{owner['username']}/passcodes", headers=staff
    )

    assert response.status_code == 200


async def test_the_stored_secret_never_appears_in_any_response(client, app_instance):
    staff = await make_staff(client, app_instance, account("quiet_staff"), "super_admin")
    secret, confirmed = await enrol(client, staff)

    me = await client.get("/v1/auth/me", headers=staff)
    assert secret not in me.text
    assert "backup_hashes" not in me.text

    status_response = await client.get("/v1/auth/totp", headers=staff)
    assert secret not in status_response.text
    for backup in confirmed.json()["data"]["backup_codes"]:
        assert backup not in status_response.text


async def test_a_stolen_session_cannot_swap_the_authenticator(client, app_instance):
    owner_name, ticket_id = await owner_with_ticket(client, "swap_target")

    staff = await make_staff(client, app_instance, account("totp_victim"), "super_admin")
    await enrol(client, staff)

    removed = await client.post("/v1/auth/totp/disable", json={}, headers=staff)
    assert removed.status_code == 422

    still_on = await client.get("/v1/auth/totp", headers=staff)
    assert still_on.json()["data"]["enabled"] is True

    fresh = await client.post("/v1/auth/totp/setup", headers=staff)
    assert fresh.status_code == 409

    denied = await client.post(
        f"/v1/admin/vault/{owner_name}/release",
        json={
            "ticket_id": ticket_id,
            "justification": "Owner verified by email and answered every precondition.",
            "totp_code": "000000",
        },
        headers=staff,
    )
    assert denied.status_code == 403


async def test_removing_the_authenticator_needs_the_current_code(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_off_a"), "super_admin")
    secret, _ = await enrol(client, staff)

    wrong = await client.post(
        "/v1/auth/totp/disable", json={"code": "000000"}, headers=staff
    )
    assert wrong.status_code == 403

    right = await client.post(
        "/v1/auth/totp/disable",
        json={"code": code_at(secret, int(time.time()))},
        headers=staff,
    )
    assert right.status_code == 200

    status_response = await client.get("/v1/auth/totp", headers=staff)
    assert status_response.json()["data"]["enabled"] is False


async def test_a_backup_code_can_also_remove_the_authenticator(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_off_b"), "super_admin")
    _, confirmed = await enrol(client, staff)
    backup = confirmed.json()["data"]["backup_codes"][0]

    response = await client.post(
        "/v1/auth/totp/disable", json={"code": backup}, headers=staff
    )
    assert response.status_code == 200


async def test_enrolling_and_removing_are_both_audited(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_audit"), "super_admin")
    secret, _ = await enrol(client, staff)
    await client.post(
        "/v1/auth/totp/disable",
        json={"code": code_at(secret, int(time.time()))},
        headers=staff,
    )

    entries = (await client.get("/v1/admin/audit", headers=staff)).json()["data"]["items"]
    actions = [entry["action"] for entry in entries]
    assert "totp.enabled" in actions
    assert "totp.disabled" in actions


async def test_the_old_delete_route_is_gone(client, app_instance):
    staff = await make_staff(client, app_instance, account("totp_off_c"), "super_admin")
    await enrol(client, staff)

    response = await client.delete("/v1/auth/totp", headers=staff)
    assert response.status_code in (404, 405)
