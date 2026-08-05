import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


@pytest.fixture
def follower():
    return account("follower_one")


async def publish(client, headers, body="A story in a room.", community=None):
    story = (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()["data"][
        "story"
    ]
    payload = {"visibility": "public"}
    if community:
        payload["community_slug"] = community
    await client.post(f"/v1/stories/{story['story_id']}/publish", json=payload, headers=headers)
    return story


async def test_a_new_follower_notifies_you(client, signup_payload, follower):
    me = await auth_headers(client, signup_payload)
    them = await auth_headers(client, follower)

    await client.post(f"/v1/connections/{signup_payload['username']}", headers=them)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert items[0]["kind"] == "new_follower"
    assert items[0]["actor"]["display_name"] == follower["username"]


async def test_unfollowing_withdraws_the_follower_notification(client, signup_payload, follower):
    me = await auth_headers(client, signup_payload)
    them = await auth_headers(client, follower)

    await client.post(f"/v1/connections/{signup_payload['username']}", headers=them)
    await client.delete(f"/v1/connections/{signup_payload['username']}", headers=them)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert items == []


async def test_a_community_story_notifies_other_members(client, signup_payload, follower):
    me = await auth_headers(client, signup_payload)
    them = await auth_headers(client, follower)

    slug = (await client.get("/v1/communities", headers=me)).json()["data"]["items"][0]["slug"]
    await client.post(f"/v1/communities/{slug}/join", headers=me)
    await client.post(f"/v1/communities/{slug}/join", headers=them)

    await publish(client, them, community=slug)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert any(item["kind"] == "community_story" for item in items)


async def test_a_community_story_does_not_notify_the_author(client, signup_payload):
    me = await auth_headers(client, signup_payload)
    slug = (await client.get("/v1/communities", headers=me)).json()["data"]["items"][0]["slug"]
    await client.post(f"/v1/communities/{slug}/join", headers=me)
    await publish(client, me, community=slug)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert items == []


async def test_a_non_member_is_not_notified(client, signup_payload, follower):
    me = await auth_headers(client, signup_payload)
    them = await auth_headers(client, follower)

    slug = (await client.get("/v1/communities", headers=me)).json()["data"]["items"][0]["slug"]
    await client.post(f"/v1/communities/{slug}/join", headers=them)
    await publish(client, them, community=slug)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert items == []


async def test_deactivating_blocks_further_requests(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/users/me/deactivate",
        json={"password": signup_payload["password"]},
        headers=headers,
    )
    assert response.status_code == 200
    assert (await client.get("/v1/auth/me", headers=headers)).status_code == 401


async def test_deactivating_requires_the_password(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/users/me/deactivate", json={"password": "wrong-one"}, headers=headers
    )
    assert response.status_code == 401


async def test_signing_in_reactivates_the_account(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/users/me/deactivate",
        json={"password": signup_payload["password"]},
        headers=headers,
    )

    signin = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert signin.status_code == 200
    assert signin.json()["data"]["user"]["status"] == "active"


async def test_a_deactivated_users_stories_leave_the_feed(client, signup_payload, follower):
    author = await auth_headers(client, signup_payload)
    story = await publish(client, author, body="Written before leaving.")
    await client.post(
        "/v1/users/me/deactivate",
        json={"password": signup_payload["password"]},
        headers=author,
    )

    reader = await auth_headers(client, follower)
    items = (await client.get("/v1/stories/feed", headers=reader)).json()["data"]["items"]
    assert all(item["story_id"] != story["story_id"] for item in items)


async def test_deleting_schedules_removal(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/users/me/delete",
        json={"password": signup_payload["password"], "acknowledged": True},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["data"]["deletes_at"].endswith("Z")


async def test_deleting_requires_acknowledgement(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/users/me/delete",
        json={"password": signup_payload["password"], "acknowledged": False},
        headers=headers,
    )
    assert response.status_code == 422


async def test_a_pending_deletion_account_cannot_sign_in(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/users/me/delete",
        json={"password": signup_payload["password"], "acknowledged": True},
        headers=headers,
    )

    signin = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert signin.status_code == 403
    assert signin.json()["data"]["code"] == "ACCOUNT_DEACTIVATED"


async def test_cancelling_a_deletion_restores_the_account(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/users/me/delete",
        json={"password": signup_payload["password"], "acknowledged": True},
        headers=headers,
    )

    cancel = await client.post(
        "/v1/users/me/delete/cancel",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert cancel.status_code == 200

    signin = await client.post(
        "/v1/auth/signin",
        json={
            "username": signup_payload["username"],
            "password": signup_payload["password"],
        },
    )
    assert signin.status_code == 200


async def test_a_deleted_username_stays_reserved_during_the_grace_period(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await client.post(
        "/v1/users/me/delete",
        json={"password": signup_payload["password"], "acknowledged": True},
        headers=headers,
    )

    response = await client.post("/v1/auth/signup", json=signup_payload)
    assert response.status_code == 409
