import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def make_staff(client, app_instance, payload, role):
    await auth_headers(client, payload)
    await app_instance.state.mongo_db["users"].update_one(
        {"username_lower": payload["username"]}, {"$set": {"role": role}}
    )
    signin = await client.post(
        "/v1/auth/signin",
        json={"username": payload["username"], "password": payload["password"]},
    )
    token = signin.json()["data"]["tokens"]["access_token"]
    return {"authorization": f"Bearer {token}"}


@pytest.fixture
def writer():
    return account("watched_writer")


async def publish(client, headers, body="Something reportable."):
    story = (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()["data"][
        "story"
    ]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story


async def test_a_plain_user_cannot_reach_the_admin_surface(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/admin/reports", headers=headers)
    assert response.status_code == 403
    assert response.json()["data"]["code"] == "ROLE_REQUIRED"


async def test_the_admin_surface_needs_a_session(client):
    response = await client.get("/v1/admin/reports")
    assert response.status_code == 401


async def test_a_moderator_sees_the_report_queue(client, signup_payload, writer, app_instance):
    author = await auth_headers(client, writer)
    story = await publish(client, author)

    reporter = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/reports",
        json={"target_kind": "story", "target_id": story["story_id"], "reason": "spam"},
        headers=reporter,
    )

    staff = await make_staff(client, app_instance, account("mod_one"), "moderator")
    response = await client.get("/v1/admin/reports", headers=staff)

    assert response.status_code == 200
    items = response.json()["data"]["items"]
    assert len(items) == 1
    assert items[0]["reason"] == "spam"
    assert items[0]["target"]["excerpt"]


async def test_a_report_can_be_dismissed(client, signup_payload, writer, app_instance):
    author = await auth_headers(client, writer)
    story = await publish(client, author)
    reporter = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/reports",
        json={"target_kind": "story", "target_id": story["story_id"], "reason": "spam"},
        headers=reporter,
    )

    staff = await make_staff(client, app_instance, account("mod_two"), "moderator")
    report_id = (await client.get("/v1/admin/reports", headers=staff)).json()["data"]["items"][0][
        "report_id"
    ]

    response = await client.post(
        f"/v1/admin/reports/{report_id}/resolve",
        json={"outcome": "dismissed"},
        headers=staff,
    )
    assert response.status_code == 200

    remaining = (await client.get("/v1/admin/reports", headers=staff)).json()["data"]["items"]
    assert remaining == []


async def test_actioning_a_report_removes_the_story(client, signup_payload, writer, app_instance):
    author = await auth_headers(client, writer)
    story = await publish(client, author)
    reporter = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/reports",
        json={"target_kind": "story", "target_id": story["story_id"], "reason": "spam"},
        headers=reporter,
    )

    staff = await make_staff(client, app_instance, account("mod_three"), "moderator")
    report_id = (await client.get("/v1/admin/reports", headers=staff)).json()["data"]["items"][0][
        "report_id"
    ]

    await client.post(
        f"/v1/admin/reports/{report_id}/resolve",
        json={"outcome": "actioned"},
        headers=staff,
    )

    response = await client.get(f"/v1/stories/{story['story_id']}", headers=author)
    assert response.status_code == 404


async def test_a_moderator_cannot_block_an_account(client, writer, app_instance):
    await signup(client, writer)
    staff = await make_staff(client, app_instance, account("mod_four"), "moderator")

    response = await client.post(
        f"/v1/admin/users/{writer['username']}/block",
        json={"reason": "spam"},
        headers=staff,
    )
    assert response.status_code == 403


async def test_an_admin_can_block_an_account(client, writer, app_instance):
    await signup(client, writer)
    staff = await make_staff(client, app_instance, account("admin_one"), "admin")

    response = await client.post(
        f"/v1/admin/users/{writer['username']}/block",
        json={"reason": "spam"},
        headers=staff,
    )
    assert response.status_code == 200

    signin = await client.post(
        "/v1/auth/signin",
        json={"username": writer["username"], "password": writer["password"]},
    )
    assert signin.status_code == 403


async def test_a_blocked_account_can_be_unblocked(client, writer, app_instance):
    await signup(client, writer)
    staff = await make_staff(client, app_instance, account("admin_two"), "admin")

    await client.post(
        f"/v1/admin/users/{writer['username']}/block",
        json={"reason": "spam"},
        headers=staff,
    )
    await client.post(f"/v1/admin/users/{writer['username']}/unblock", headers=staff)

    signin = await client.post(
        "/v1/auth/signin",
        json={"username": writer["username"], "password": writer["password"]},
    )
    assert signin.status_code == 200


async def test_admin_user_lookup_returns_metadata_only(client, writer, app_instance):
    await signup(client, writer)
    staff = await make_staff(client, app_instance, account("admin_three"), "admin")

    response = await client.get(f"/v1/admin/users/{writer['username']}", headers=staff)
    assert response.status_code == 200

    body = response.text
    assert "password_hash" not in body
    assert "email_ciphertext" not in body


async def test_admin_stats_report_the_platform(client, signup_payload, app_instance):
    author = await auth_headers(client, signup_payload)
    await publish(client, author)

    staff = await make_staff(client, app_instance, account("admin_four"), "admin")
    response = await client.get("/v1/admin/stats", headers=staff)

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["users"] >= 1
    assert data["stories"] >= 1


async def test_every_admin_action_is_audited(client, writer, app_instance):
    await signup(client, writer)
    staff = await make_staff(client, app_instance, account("admin_five"), "admin")

    await client.post(
        f"/v1/admin/users/{writer['username']}/block",
        json={"reason": "spam"},
        headers=staff,
    )

    response = await client.get("/v1/admin/audit", headers=staff)
    entries = response.json()["data"]["items"]
    assert any(entry["action"] == "account.blocked" for entry in entries)
    assert entries[0]["actor"]["username"] == "admin_five"


async def test_the_audit_log_cannot_be_written_through_the_api(client, app_instance):
    staff = await make_staff(client, app_instance, account("admin_six"), "admin")
    response = await client.post("/v1/admin/audit", json={}, headers=staff)
    assert response.status_code in (404, 405)


async def test_there_is_no_impersonation_endpoint(client, writer, app_instance):
    await signup(client, writer)
    staff = await make_staff(client, app_instance, account("super_one"), "super_admin")

    response = await client.post(f"/v1/admin/users/{writer['username']}/impersonate", headers=staff)
    assert response.status_code == 404
