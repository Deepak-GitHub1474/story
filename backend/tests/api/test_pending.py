from datetime import timedelta

import pytest

from app.core.time import utc_now


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


@pytest.fixture
def reader():
    return account("pending_reader")


async def draft(client, headers, body="Something written ahead of time."):
    return (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()["data"][
        "story"
    ]


def in_future(minutes=30):
    return (utc_now() + timedelta(minutes=minutes)).isoformat().replace("+00:00", "Z")


def in_past(minutes=5):
    return (utc_now() - timedelta(minutes=minutes)).isoformat().replace("+00:00", "Z")


async def test_a_story_can_be_scheduled(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_future()},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["data"]["story"]["visibility"] == "scheduled"


async def test_scheduling_requires_a_time(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled"},
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "SCHEDULE_REQUIRED"


async def test_a_schedule_in_the_past_is_rejected(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)

    response = await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_past()},
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["data"]["code"] == "SCHEDULE_IN_PAST"


async def test_a_scheduled_story_is_not_in_the_feed(client, signup_payload, reader):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_future()},
        headers=headers,
    )

    other = await auth_headers(client, reader)
    items = (await client.get("/v1/stories/feed", headers=other)).json()["data"]["items"]
    assert all(item["story_id"] != story["story_id"] for item in items)


async def test_a_scheduled_story_is_invisible_to_others(client, signup_payload, reader):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_future()},
        headers=headers,
    )

    other = await auth_headers(client, reader)
    response = await client.get(f"/v1/stories/{story['story_id']}", headers=other)
    assert response.status_code == 404


async def test_the_sweep_publishes_a_due_story(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_future()},
        headers=headers,
    )

    await app_instance.state.mongo_db["stories"].update_one(
        {"_id": story["story_id"]},
        {"$set": {"scheduled_for": utc_now() - timedelta(minutes=1)}},
    )

    from app.workers.maintenance import publish_scheduled_stories

    published = await publish_scheduled_stories(app_instance.state.mongo_db)
    assert published == 1

    detail = (await client.get(f"/v1/stories/{story['story_id']}", headers=headers)).json()["data"][
        "story"
    ]
    assert detail["visibility"] == "public"
    assert detail["slug"]


async def test_the_sweep_leaves_future_stories_alone(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_future()},
        headers=headers,
    )

    from app.workers.maintenance import publish_scheduled_stories

    assert await publish_scheduled_stories(app_instance.state.mongo_db) == 0


async def test_the_sweep_counts_the_story_once(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "scheduled", "scheduled_for": in_future()},
        headers=headers,
    )
    await app_instance.state.mongo_db["stories"].update_one(
        {"_id": story["story_id"]},
        {"$set": {"scheduled_for": utc_now() - timedelta(minutes=1)}},
    )

    from app.workers.maintenance import publish_scheduled_stories

    await publish_scheduled_stories(app_instance.state.mongo_db)
    await publish_scheduled_stories(app_instance.state.mongo_db)

    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    assert me["counts"]["stories"] == 1


async def test_a_comment_can_be_edited_inside_the_window(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "First thought."},
            headers=headers,
        )
    ).json()["data"]["comment"]

    response = await client.patch(
        f"/v1/comments/{comment['comment_id']}",
        json={"body": "Better thought."},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["data"]["comment"]["body"] == "Better thought."


async def test_another_user_cannot_edit_your_comment(client, signup_payload, reader):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Mine."},
            headers=headers,
        )
    ).json()["data"]["comment"]

    other = await auth_headers(client, reader)
    response = await client.patch(
        f"/v1/comments/{comment['comment_id']}",
        json={"body": "Not yours."},
        headers=other,
    )
    assert response.status_code == 404


async def test_a_comment_cannot_be_edited_after_the_window(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Too late to change."},
            headers=headers,
        )
    ).json()["data"]["comment"]

    await app_instance.state.mongo_db["comments"].update_one(
        {"_id": comment["comment_id"]},
        {"$set": {"created_at": utc_now() - timedelta(hours=1)}},
    )

    response = await client.patch(
        f"/v1/comments/{comment['comment_id']}",
        json={"body": "Sneaking an edit in."},
        headers=headers,
    )
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "COMMENT_NOT_EDITABLE"


async def test_a_retried_story_creation_makes_one_story(client, signup_payload):
    headers = {**await auth_headers(client, signup_payload), "idempotency-key": "abc-123"}
    body = {"body": "Sent twice because the network hiccuped."}

    first = await client.post("/v1/stories", json=body, headers=headers)
    second = await client.post("/v1/stories", json=body, headers=headers)

    assert first.status_code == second.status_code == 201
    assert first.json()["data"]["story"]["story_id"] == second.json()["data"]["story"]["story_id"]

    mine = (await client.get("/v1/stories/mine", headers=headers)).json()["data"]["items"]
    assert len(mine) == 1


async def test_a_different_key_makes_a_different_story(client, signup_payload):
    base = await auth_headers(client, signup_payload)
    body = {"body": "Two deliberate stories."}

    await client.post("/v1/stories", json=body, headers={**base, "idempotency-key": "k1"})
    await client.post("/v1/stories", json=body, headers={**base, "idempotency-key": "k2"})

    mine = (await client.get("/v1/stories/mine", headers=base)).json()["data"]["items"]
    assert len(mine) == 2


async def test_a_retried_comment_posts_once(client, signup_payload):
    base = await auth_headers(client, signup_payload)
    story = await draft(client, base)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=base,
    )

    headers = {**base, "idempotency-key": "comment-1"}
    body = {"body": "Only once."}
    await client.post(f"/v1/stories/{story['story_id']}/comments", json=body, headers=headers)
    await client.post(f"/v1/stories/{story['story_id']}/comments", json=body, headers=headers)

    items = (await client.get(f"/v1/stories/{story['story_id']}/comments", headers=base)).json()[
        "data"
    ]["items"]
    assert len(items) == 1


async def test_another_users_key_does_not_collide(client, signup_payload, reader):
    mine = {**await auth_headers(client, signup_payload), "idempotency-key": "shared"}
    theirs = {**await auth_headers(client, reader), "idempotency-key": "shared"}

    first = await client.post("/v1/stories", json={"body": "Mine."}, headers=mine)
    second = await client.post("/v1/stories", json={"body": "Theirs."}, headers=theirs)

    assert first.json()["data"]["story"]["story_id"] != second.json()["data"]["story"]["story_id"]


async def test_count_reconciliation_repairs_a_drifted_counter(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)
    story = await draft(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )

    await app_instance.state.mongo_db["users"].update_one(
        {"username_lower": signup_payload["username"]},
        {"$set": {"counts.stories": 99}},
    )

    from app.workers.maintenance import reconcile_counts

    await reconcile_counts(app_instance.state.mongo_db)

    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    assert me["counts"]["stories"] == 1
