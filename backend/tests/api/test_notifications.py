import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


@pytest.fixture
def reader_payload():
    return {
        "username": "thereader",
        "password": "another-long-password",
        "tnc_accepted": True,
    }


async def published_story(client, headers, body="A story worth reading twice."):
    story = (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()["data"][
        "story"
    ]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story


async def test_notifications_start_empty(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/notifications", headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["items"] == []


async def test_a_like_notifies_the_author(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)

    reader = await auth_headers(client, reader_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert len(items) == 1
    assert items[0]["kind"] == "story_like"
    assert items[0]["target"]["id"] == story["story_id"]


async def test_a_like_notification_names_the_actor(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert items[0]["actor"]["display_name"] == reader_payload["username"]
    assert items[0]["actor"]["avatar_seed"]


async def test_liking_your_own_story_notifies_nobody(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=author)

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert items == []


async def test_unliking_removes_the_notification(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)

    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)
    await client.delete(f"/v1/stories/{story['story_id']}/like", headers=reader)

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert items == []


async def test_relike_does_not_duplicate_the_notification(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)

    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert len(items) == 1


async def test_a_comment_notifies_the_author(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)

    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "This landed."},
        headers=reader,
    )

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert items[0]["kind"] == "story_comment"
    assert "This landed." in items[0]["body"]


async def test_commenting_on_your_own_story_notifies_nobody(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Talking to myself."},
        headers=author,
    )
    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert items == []


async def test_a_reply_notifies_the_parent_comment_author(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)

    parent = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "First thought."},
            headers=reader,
        )
    ).json()["data"]["comment"]

    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Replying to you.", "parent_id": parent["comment_id"]},
        headers=author,
    )

    items = (await client.get("/v1/notifications", headers=reader)).json()["data"]["items"]
    assert any(item["kind"] == "comment_reply" for item in items)


async def test_unread_count_reflects_unread_notifications(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    response = await client.get("/v1/notifications/unread-count", headers=author)
    assert response.json()["data"]["unread"] == 1


async def test_marking_one_read_lowers_the_count(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    await client.post(f"/v1/notifications/{items[0]['notification_id']}/read", headers=author)

    count = (await client.get("/v1/notifications/unread-count", headers=author)).json()["data"][
        "unread"
    ]
    assert count == 0


async def test_marking_all_read_clears_the_count(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)
    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "And a comment."},
        headers=reader,
    )

    await client.post("/v1/notifications/read-all", headers=author)
    count = (await client.get("/v1/notifications/unread-count", headers=author)).json()["data"][
        "unread"
    ]
    assert count == 0


async def test_notifications_are_newest_first(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)

    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)
    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Later than the like."},
        headers=reader,
    )

    items = (await client.get("/v1/notifications", headers=author)).json()["data"]["items"]
    assert items[0]["kind"] == "story_comment"


async def test_a_user_never_sees_another_users_notifications(
    client, signup_payload, reader_payload
):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=reader)

    items = (await client.get("/v1/notifications", headers=reader)).json()["data"]["items"]
    assert items == []


async def test_replies_are_listed_under_their_parent(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    reader = await auth_headers(client, reader_payload)

    parent = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Top level."},
            headers=author,
        )
    ).json()["data"]["comment"]

    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "A reply.", "parent_id": parent["comment_id"]},
        headers=reader,
    )

    items = (await client.get(f"/v1/stories/{story['story_id']}/comments", headers=author)).json()[
        "data"
    ]["items"]

    assert len(items) == 1
    assert items[0]["counts"]["replies"] == 1
    assert items[0]["replies"][0]["body"] == "A reply."


async def test_a_thread_can_be_expanded(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await published_story(client, headers)
    parent = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Parent."},
            headers=headers,
        )
    ).json()["data"]["comment"]

    for index in range(5):
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": f"reply {index}", "parent_id": parent["comment_id"]},
            headers=headers,
        )

    replies = (
        await client.get(f"/v1/comments/{parent['comment_id']}/replies", headers=headers)
    ).json()["data"]["items"]
    assert len(replies) == 5


async def test_comment_likes_are_counted(client, signup_payload, reader_payload):
    author = await auth_headers(client, signup_payload)
    story = await published_story(client, author)
    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Like this comment."},
            headers=author,
        )
    ).json()["data"]["comment"]

    reader = await auth_headers(client, reader_payload)
    response = await client.post(f"/v1/comments/{comment['comment_id']}/like", headers=reader)
    assert response.json()["data"]["likes"] == 1


async def test_commenting_twice_on_the_same_story_does_not_error(client, signup_payload):
    author = await auth_headers(client, signup_payload)
    story = (
        await client.post("/v1/stories", json={"body": "Say something."}, headers=author)
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=author,
    )

    reader = await auth_headers(
        client,
        {"username": "twice_over", "password": "another-long-password", "tnc_accepted": True},
    )

    first = await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "The first thing I thought."},
        headers=reader,
    )
    second = await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "And then another thing."},
        headers=reader,
    )

    assert first.status_code == 201
    assert second.status_code == 201


async def test_replying_to_your_own_comment_works(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (
        await client.post("/v1/stories", json={"body": "Say something."}, headers=headers)
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )

    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "A thought of my own."},
            headers=headers,
        )
    ).json()["data"]["comment"]

    reply = await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Following up on myself.", "parent_id": comment["comment_id"]},
        headers=headers,
    )

    assert reply.status_code == 201
