import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


@pytest.fixture
def author():
    return account("reported_one")


async def publish(client, headers, body="Something to report."):
    story = (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()["data"][
        "story"
    ]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story


async def test_reporting_a_story_is_accepted(client, signup_payload, author):
    writer = await auth_headers(client, author)
    story = await publish(client, writer)

    reader = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/reports",
        json={"target_kind": "story", "target_id": story["story_id"], "reason": "spam"},
        headers=reader,
    )
    assert response.status_code == 201
    assert response.json()["data"]["reported"] is True


async def test_reporting_the_same_thing_twice_is_idempotent(
    client, signup_payload, author, app_instance
):
    writer = await auth_headers(client, author)
    story = await publish(client, writer)
    reader = await auth_headers(client, signup_payload)

    body = {"target_kind": "story", "target_id": story["story_id"], "reason": "spam"}
    await client.post("/v1/reports", json=body, headers=reader)
    await client.post("/v1/reports", json=body, headers=reader)

    count = await app_instance.state.mongo_db["reports"].count_documents({})
    assert count == 1


async def test_reporting_an_unknown_story_is_rejected(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/reports",
        json={"target_kind": "story", "target_id": "sto_nope", "reason": "spam"},
        headers=headers,
    )
    assert response.status_code == 404


async def test_you_cannot_report_yourself(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/reports",
        json={
            "target_kind": "user",
            "target_id": signup_payload["username"],
            "reason": "spam",
        },
        headers=headers,
    )
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "SELF_REPORT"


async def test_an_unknown_reason_is_rejected(client, signup_payload, author):
    writer = await auth_headers(client, author)
    story = await publish(client, writer)
    reader = await auth_headers(client, signup_payload)

    response = await client.post(
        "/v1/reports",
        json={
            "target_kind": "story",
            "target_id": story["story_id"],
            "reason": "i_just_dislike_it",
        },
        headers=reader,
    )
    assert response.status_code == 422


async def test_a_vault_item_can_never_be_reported(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/reports",
        json={"target_kind": "vault_item", "target_id": "vit_1", "reason": "spam"},
        headers=headers,
    )
    assert response.status_code == 422


async def test_reporting_a_comment_works(client, signup_payload, author):
    writer = await auth_headers(client, author)
    story = await publish(client, writer)
    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Report this comment."},
            headers=writer,
        )
    ).json()["data"]["comment"]

    reader = await auth_headers(client, signup_payload)
    response = await client.post(
        "/v1/reports",
        json={
            "target_kind": "comment",
            "target_id": comment["comment_id"],
            "reason": "harassment",
        },
        headers=reader,
    )
    assert response.status_code == 201


async def test_reporting_a_user_works(client, signup_payload, author):
    await signup(client, author)
    reader = await auth_headers(client, signup_payload)

    response = await client.post(
        "/v1/reports",
        json={
            "target_kind": "user",
            "target_id": author["username"],
            "reason": "impersonation",
            "note": "Pretending to be someone else.",
        },
        headers=reader,
    )
    assert response.status_code == 201


async def test_the_report_records_who_and_what(client, signup_payload, author, app_instance):
    writer = await auth_headers(client, author)
    story = await publish(client, writer)
    reader = await auth_headers(client, signup_payload)

    await client.post(
        "/v1/reports",
        json={
            "target_kind": "story",
            "target_id": story["story_id"],
            "reason": "self_harm",
        },
        headers=reader,
    )

    report = await app_instance.state.mongo_db["reports"].find_one({})
    assert report["target_kind"] == "story"
    assert report["reason"] == "self_harm"
    assert report["state"] == "open"


async def test_notification_preferences_can_be_turned_off(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.patch(
        "/v1/users/me", json={"prefs": {"notify_in_app": False}}, headers=headers
    )
    assert response.json()["data"]["user"]["prefs"]["notify_in_app"] is False


async def test_turning_notifications_off_stops_new_ones(client, signup_payload, author):
    me = await auth_headers(client, signup_payload)
    await client.patch("/v1/users/me", json={"prefs": {"notify_in_app": False}}, headers=me)

    story = await publish(client, me, body="Nobody tell me about this.")
    them = await auth_headers(client, author)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=them)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert items == []


async def test_notifications_still_arrive_when_left_on(client, signup_payload, author):
    me = await auth_headers(client, signup_payload)
    story = await publish(client, me, body="Do tell me about this.")
    them = await auth_headers(client, author)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=them)

    items = (await client.get("/v1/notifications", headers=me)).json()["data"]["items"]
    assert len(items) == 1
