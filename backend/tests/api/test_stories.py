import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


@pytest.fixture
def other_payload():
    return {
        "username": "otherwriter",
        "password": "another-long-password",
        "tnc_accepted": True,
    }


async def create_story(client, headers, **overrides):
    body = {"title": "A quiet year", "body": "It has been a long year." * 3, **overrides}
    return await client.post("/v1/stories", json=body, headers=headers)


async def published(client, headers, **overrides):
    story = (await create_story(client, headers, **overrides)).json()["data"]["story"]
    return (
        await client.post(
            f"/v1/stories/{story['story_id']}/publish",
            json={"visibility": "public"},
            headers=headers,
        )
    ).json()["data"]["story"]


async def test_create_returns_a_draft(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await create_story(client, headers)
    assert response.status_code == 201
    assert response.json()["data"]["story"]["visibility"] == "draft"


async def test_create_ignores_a_client_supplied_visibility(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await create_story(client, headers, visibility="public")
    assert response.status_code in (201, 422)
    if response.status_code == 201:
        assert response.json()["data"]["story"]["visibility"] == "draft"


async def test_create_derives_an_excerpt(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    assert story["excerpt"]
    assert len(story["excerpt"]) <= 240


async def test_create_derives_reading_minutes(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    assert story["reading_minutes"] >= 1


async def test_create_carries_the_author_snapshot(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    assert story["author"]["display_name"] == signup_payload["username"]
    assert story["author"]["avatar_seed"]


async def test_create_rejects_an_empty_body(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await create_story(client, headers, body="")
    assert response.status_code == 422


async def test_create_rejects_an_overlong_body(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await create_story(client, headers, body="x" * 20001)
    assert response.status_code == 422


async def test_update_changes_the_body_and_reexcerpts(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    response = await client.patch(
        f"/v1/stories/{story['story_id']}",
        json={"body": "Something else entirely now."},
        headers=headers,
    )
    assert response.json()["data"]["story"]["excerpt"].startswith("Something else")


async def test_update_rejects_another_users_story(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    other = await auth_headers(client, other_payload)
    response = await client.patch(
        f"/v1/stories/{story['story_id']}", json={"body": "Mine now."}, headers=other
    )
    assert response.status_code == 404


async def test_publish_makes_a_story_public(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    response = await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    assert response.status_code == 200
    published = response.json()["data"]["story"]
    assert published["visibility"] == "public"
    assert published["published_at"].endswith("Z")


async def test_publish_generates_an_opaque_slug(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers, title="My Secret Divorce")).json()["data"]["story"]
    published = (
        await client.post(
            f"/v1/stories/{story['story_id']}/publish",
            json={"visibility": "public"},
            headers=headers,
        )
    ).json()["data"]["story"]
    assert published["slug"]
    assert "divorce" not in published["slug"].lower()


async def test_published_at_is_truncated_to_the_minute(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    published = (
        await client.post(
            f"/v1/stories/{story['story_id']}/publish",
            json={"visibility": "public"},
            headers=headers,
        )
    ).json()["data"]["story"]
    assert published["published_at"].endswith(":00.000Z")


async def test_publish_as_private_keeps_it_hidden_from_others(
    client, signup_payload, other_payload
):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "private"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.get(f"/v1/stories/{story['story_id']}", headers=other)
    assert response.status_code == 404


async def test_a_draft_is_invisible_to_others(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    other = await auth_headers(client, other_payload)
    response = await client.get(f"/v1/stories/{story['story_id']}", headers=other)
    assert response.status_code == 404


async def test_a_public_story_is_visible_to_others(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.get(f"/v1/stories/{story['story_id']}", headers=other)
    assert response.status_code == 200


async def test_unpublish_returns_a_story_to_draft(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    response = await client.post(f"/v1/stories/{story['story_id']}/unpublish", headers=headers)
    assert response.json()["data"]["story"]["visibility"] == "draft"


async def test_mine_lists_own_stories(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await create_story(client, headers)
    await create_story(client, headers)
    response = await client.get("/v1/stories/mine", headers=headers)
    assert len(response.json()["data"]["items"]) == 2


async def test_mine_filters_by_visibility(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    first = (await create_story(client, headers)).json()["data"]["story"]
    await create_story(client, headers)
    await client.post(
        f"/v1/stories/{first['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    response = await client.get("/v1/stories/mine?visibility=draft", headers=headers)
    assert len(response.json()["data"]["items"]) == 1


async def test_delete_removes_it_from_mine(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.delete(f"/v1/stories/{story['story_id']}", headers=headers)
    response = await client.get("/v1/stories/mine", headers=headers)
    assert response.json()["data"]["items"] == []


async def test_feed_shows_public_stories(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.get("/v1/stories/feed", headers=other)
    assert len(response.json()["data"]["items"]) == 1


async def test_feed_excludes_drafts_and_private(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    await create_story(client, headers)
    private = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{private['story_id']}/publish",
        json={"visibility": "private"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.get("/v1/stories/feed", headers=other)
    assert response.json()["data"]["items"] == []


async def test_feed_paginates_with_a_cursor(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    for _ in range(3):
        story = (await create_story(client, headers)).json()["data"]["story"]
        await client.post(
            f"/v1/stories/{story['story_id']}/publish",
            json={"visibility": "public"},
            headers=headers,
        )
    other = await auth_headers(client, other_payload)
    first = (await client.get("/v1/stories/feed?limit=2", headers=other)).json()["data"]
    assert len(first["items"]) == 2
    assert first["has_more"] is True

    second = (
        await client.get(f"/v1/stories/feed?limit=2&cursor={first['next_cursor']}", headers=other)
    ).json()["data"]
    assert len(second["items"]) == 1
    assert second["has_more"] is False


async def test_feed_never_returns_full_bodies(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers, body="UNIQUE_MARKER " * 40)).json()["data"][
        "story"
    ]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.get("/v1/stories/feed", headers=other)
    assert "body" not in response.json()["data"]["items"][0]


async def test_liking_increments_the_count(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.post(f"/v1/stories/{story['story_id']}/like", headers=other)
    assert response.json()["data"]["likes"] == 1


async def test_liking_twice_counts_once(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=other)
    response = await client.post(f"/v1/stories/{story['story_id']}/like", headers=other)
    assert response.json()["data"]["likes"] == 1


async def test_unliking_decrements(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=other)
    response = await client.delete(f"/v1/stories/{story['story_id']}/like", headers=other)
    assert response.json()["data"]["likes"] == 0


async def test_story_detail_reports_whether_i_liked_it(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=other)
    detail = (await client.get(f"/v1/stories/{story['story_id']}", headers=other)).json()["data"][
        "story"
    ]
    assert detail["is_liked"] is True


async def test_commenting_returns_the_comment(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "I read this twice."},
        headers=other,
    )
    assert response.status_code == 201
    assert response.json()["data"]["comment"]["body"] == "I read this twice."


async def test_comments_are_listed_oldest_first(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    for text in ("first", "second"):
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": text},
            headers=headers,
        )
    items = (await client.get(f"/v1/stories/{story['story_id']}/comments", headers=headers)).json()[
        "data"
    ]["items"]
    assert [item["body"] for item in items] == ["first", "second"]


async def test_commenting_increments_the_story_count(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Here."},
        headers=headers,
    )
    detail = (await client.get(f"/v1/stories/{story['story_id']}", headers=headers)).json()["data"][
        "story"
    ]
    assert detail["counts"]["comments"] == 1


async def test_cannot_comment_on_another_users_draft(client, signup_payload, other_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    other = await auth_headers(client, other_payload)
    response = await client.post(
        f"/v1/stories/{story['story_id']}/comments",
        json={"body": "Sneaking in."},
        headers=other,
    )
    assert response.status_code == 404


async def test_author_can_delete_a_comment(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    comment = (
        await client.post(
            f"/v1/stories/{story['story_id']}/comments",
            json={"body": "Delete me."},
            headers=headers,
        )
    ).json()["data"]["comment"]
    response = await client.delete(f"/v1/comments/{comment['comment_id']}", headers=headers)
    assert response.status_code == 200


async def test_profile_stories_lists_public_stories_of_a_user(
    client, signup_payload, other_payload
):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await create_story(client, headers)
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    other = await auth_headers(client, other_payload)
    response = await client.get(f"/v1/users/{signup_payload['username']}/stories", headers=other)
    assert len(response.json()["data"]["items"]) == 1


async def test_story_counts_update_on_the_author_profile(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = (await create_story(client, headers)).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    user = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    assert user["counts"]["stories"] == 1


async def test_a_story_i_liked_shows_as_liked_in_my_feed(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await published(client, headers)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=headers)

    feed = (await client.get("/v1/stories/feed", headers=headers)).json()["data"]["items"]
    mine = next(item for item in feed if item["story_id"] == story["story_id"])

    assert mine["is_liked"] is True


async def test_a_story_i_liked_shows_as_liked_on_my_profile(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    story = await published(client, headers)
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=headers)

    items = (await client.get("/v1/stories/mine", headers=headers)).json()["data"]["items"]

    assert items[0]["is_liked"] is True


async def test_a_story_i_did_not_like_stays_unliked(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    await published(client, headers)

    items = (await client.get("/v1/stories/mine", headers=headers)).json()["data"]["items"]

    assert items[0]["is_liked"] is False


async def test_someone_elses_like_is_not_mine(client, signup_payload, app_instance):
    author = await auth_headers(client, signup_payload)
    story = await published(client, author)

    other = await auth_headers(
        client,
        {"username": "like_watcher", "password": "another-long-password", "tnc_accepted": True},
    )
    await client.post(f"/v1/stories/{story['story_id']}/like", headers=other)

    items = (await client.get("/v1/stories/mine", headers=author)).json()["data"]["items"]

    assert items[0]["is_liked"] is False
    assert items[0]["counts"]["likes"] == 1
