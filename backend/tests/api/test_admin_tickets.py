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


async def open_ticket(client, headers, kind):
    response = await client.post(
        "/v1/tickets",
        json={"type": kind, "reason": "I cannot get into my vault any more."},
        headers=headers,
    )
    return response.json()["data"]["ticket"]


async def test_a_plain_user_cannot_read_the_ticket_queue(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.get("/v1/admin/tickets", headers=headers)

    assert response.status_code == 403


async def test_a_moderator_sees_content_appeals_and_nothing_heavier(
    client, signup_payload, app_instance
):
    owner = await auth_headers(client, signup_payload)
    await open_ticket(client, owner, "content_appeal")
    await open_ticket(client, owner, "passcode_release")

    staff = await make_staff(client, app_instance, account("mod_one"), "moderator")

    items = (await client.get("/v1/admin/tickets", headers=staff)).json()["data"]["items"]

    assert [item["type"] for item in items] == ["content_appeal"]


async def test_an_admin_sees_account_tickets_but_never_an_escrow_release(
    client, signup_payload, app_instance
):
    owner = await auth_headers(client, signup_payload)
    await open_ticket(client, owner, "account_locked")
    await open_ticket(client, owner, "passcode_release")

    staff = await make_staff(client, app_instance, account("admin_one"), "admin")

    types = {
        item["type"]
        for item in (await client.get("/v1/admin/tickets", headers=staff)).json()["data"][
            "items"
        ]
    }

    assert "account_locked" in types
    assert "passcode_release" not in types


async def test_a_super_admin_sees_the_escrow_release_and_who_opened_it(
    client, signup_payload, app_instance
):
    owner = await auth_headers(client, signup_payload)
    ticket = await open_ticket(client, owner, "passcode_release")

    staff = await make_staff(client, app_instance, account("root_one"), "super_admin")

    items = (await client.get("/v1/admin/tickets", headers=staff)).json()["data"]["items"]
    found = next(item for item in items if item["ticket_id"] == ticket["ticket_id"])

    assert found["required_role"] == "super_admin"
    assert found["opened_by"]["username"] == signup_payload["username"]


async def test_a_closed_ticket_leaves_the_queue(client, signup_payload, app_instance):
    owner = await auth_headers(client, signup_payload)
    ticket = await open_ticket(client, owner, "account_locked")
    await app_instance.state.mongo_db["support_tickets"].update_one(
        {"_id": ticket["ticket_id"]}, {"$set": {"state": "closed"}}
    )

    staff = await make_staff(client, app_instance, account("admin_two"), "admin")

    open_now = (await client.get("/v1/admin/tickets", headers=staff)).json()["data"]["items"]
    everything = (
        await client.get("/v1/admin/tickets?include_closed=true", headers=staff)
    ).json()["data"]["items"]

    assert open_now == []
    assert [item["ticket_id"] for item in everything] == [ticket["ticket_id"]]


async def test_the_queue_is_oldest_first(client, signup_payload, app_instance):
    owner = await auth_headers(client, signup_payload)
    first = await open_ticket(client, owner, "account_locked")
    second = await open_ticket(client, owner, "data_export")

    staff = await make_staff(client, app_instance, account("admin_three"), "admin")

    items = (await client.get("/v1/admin/tickets", headers=staff)).json()["data"]["items"]

    assert [item["ticket_id"] for item in items] == [
        first["ticket_id"],
        second["ticket_id"],
    ]


async def test_the_queue_never_carries_the_openers_email(
    client, signup_payload, app_instance
):
    owner = await auth_headers(client, signup_payload)
    await open_ticket(client, owner, "account_locked")

    staff = await make_staff(client, app_instance, account("admin_four"), "admin")

    response = await client.get("/v1/admin/tickets", headers=staff)

    assert "email" not in response.text.lower()


async def test_stats_count_the_tickets_still_waiting(client, signup_payload, app_instance):
    owner = await auth_headers(client, signup_payload)
    await open_ticket(client, owner, "account_locked")

    staff = await make_staff(client, app_instance, account("admin_five"), "admin")

    stats = (await client.get("/v1/admin/stats", headers=staff)).json()["data"]

    assert stats["open_tickets"] == 1
