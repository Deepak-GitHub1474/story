async def auth_headers(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def a_notification(client, mine, signup_payload):
    theirs = await auth_headers(client, account("notif_sender"))
    story = (
        await client.post("/v1/stories", json={"body": "Read this."}, headers=mine)
    ).json()["data"]["story"]["story_id"]
    await client.post(
        f"/v1/stories/{story}/publish", json={"visibility": "public"}, headers=mine
    )
    await client.post(f"/v1/stories/{story}/like", headers=theirs)

    rows = (await client.get("/v1/notifications", headers=mine)).json()["data"]["items"]
    return rows[0]["notification_id"]


async def test_a_notification_can_be_thrown_away(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    notification_id = await a_notification(client, mine, signup_payload)

    response = await client.delete(f"/v1/notifications/{notification_id}", headers=mine)

    assert response.status_code == 200
    rows = (await client.get("/v1/notifications", headers=mine)).json()["data"]["items"]
    assert notification_id not in [row["notification_id"] for row in rows]


async def test_throwing_one_away_clears_it_from_the_unread_count(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    notification_id = await a_notification(client, mine, signup_payload)

    before = (await client.get("/v1/notifications/unread-count", headers=mine)).json()["data"]
    await client.delete(f"/v1/notifications/{notification_id}", headers=mine)
    after = (await client.get("/v1/notifications/unread-count", headers=mine)).json()["data"]

    assert after["unread"] == before["unread"] - 1


async def test_you_cannot_throw_away_someone_elses(client, signup_payload):
    mine = await auth_headers(client, signup_payload)
    notification_id = await a_notification(client, mine, signup_payload)

    stranger = await auth_headers(client, account("notif_stranger"))
    response = await client.delete(
        f"/v1/notifications/{notification_id}", headers=stranger
    )

    assert response.status_code == 404
    rows = (await client.get("/v1/notifications", headers=mine)).json()["data"]["items"]
    assert notification_id in [row["notification_id"] for row in rows]
