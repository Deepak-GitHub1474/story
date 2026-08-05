import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {
        "username": name,
        "password": "another-long-password",
        "tnc_accepted": True,
    }


async def publish(client, headers, body="A story worth reading.", community=None):
    story = (await client.post("/v1/stories", json={"body": body}, headers=headers)).json()["data"][
        "story"
    ]
    payload = {"visibility": "public"}
    if community:
        payload["community_slug"] = community
    await client.post(f"/v1/stories/{story['story_id']}/publish", json=payload, headers=headers)
    return story


@pytest.fixture
def alice():
    return account("alice_w")


@pytest.fixture
def bob():
    return account("bob_w")


async def test_communities_are_seeded_across_categories(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    response = await client.get("/v1/communities", headers=headers)
    assert response.status_code == 200
    items = response.json()["data"]["items"]
    assert len(items) >= 20
    assert len({item["category_id"] for item in items}) >= 10


async def test_communities_filter_by_category(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    items = (await client.get("/v1/communities?category=job-search", headers=headers)).json()[
        "data"
    ]["items"]
    assert items
    assert all(item["category_id"] == "job-search" for item in items)


async def test_community_detail_reports_membership(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    slug = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"][0]["slug"]
    detail = (await client.get(f"/v1/communities/{slug}", headers=headers)).json()["data"][
        "community"
    ]
    assert detail["is_member"] is False


async def test_joining_a_community_is_idempotent(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    slug = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"][0]["slug"]

    await client.post(f"/v1/communities/{slug}/join", headers=headers)
    await client.post(f"/v1/communities/{slug}/join", headers=headers)

    detail = (await client.get(f"/v1/communities/{slug}", headers=headers)).json()["data"][
        "community"
    ]
    assert detail["is_member"] is True
    assert detail["counts"]["members"] == 1


async def test_leaving_a_community_lowers_the_count(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    slug = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"][0]["slug"]
    await client.post(f"/v1/communities/{slug}/join", headers=headers)
    await client.delete(f"/v1/communities/{slug}/join", headers=headers)

    detail = (await client.get(f"/v1/communities/{slug}", headers=headers)).json()["data"][
        "community"
    ]
    assert detail["is_member"] is False
    assert detail["counts"]["members"] == 0


async def test_my_communities_lists_joined_only(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    items = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"]
    await client.post(f"/v1/communities/{items[0]['slug']}/join", headers=headers)

    mine = (await client.get("/v1/communities/me", headers=headers)).json()["data"]["items"]
    assert len(mine) == 1
    assert mine[0]["slug"] == items[0]["slug"]


async def test_publishing_into_a_community_requires_membership(client, alice):
    headers = await auth_headers(client, alice)
    slug = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"][0]["slug"]

    story = (
        await client.post("/v1/stories", json={"body": "Into the room."}, headers=headers)
    ).json()["data"]["story"]
    response = await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public", "community_slug": slug},
        headers=headers,
    )
    assert response.status_code == 403
    assert response.json()["data"]["code"] == "NOT_A_MEMBER"


async def test_a_member_can_publish_into_a_community(client, alice):
    headers = await auth_headers(client, alice)
    slug = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"][0]["slug"]
    await client.post(f"/v1/communities/{slug}/join", headers=headers)

    story = await publish(client, headers, community=slug)
    detail = (await client.get(f"/v1/stories/{story['story_id']}", headers=headers)).json()["data"][
        "story"
    ]
    assert detail["community"]["slug"] == slug


async def test_community_feed_lists_its_stories(client, alice):
    headers = await auth_headers(client, alice)
    slug = (await client.get("/v1/communities", headers=headers)).json()["data"]["items"][0]["slug"]
    await client.post(f"/v1/communities/{slug}/join", headers=headers)
    story = await publish(client, headers, community=slug)

    items = (await client.get(f"/v1/communities/{slug}/stories", headers=headers)).json()["data"][
        "items"
    ]
    assert [item["story_id"] for item in items] == [story["story_id"]]


async def test_following_creates_a_connection(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    await signup(client, bob)

    response = await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)
    assert response.status_code == 200
    assert response.json()["data"]["is_following"] is True


async def test_following_is_idempotent(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    await signup(client, bob)

    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    me = (await client.get("/v1/auth/me", headers=alice_headers)).json()["data"]["user"]
    assert me["counts"]["connections"] == 1


async def test_following_updates_both_counts(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)

    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    alice_me = (await client.get("/v1/auth/me", headers=alice_headers)).json()["data"]["user"]
    bob_me = (await client.get("/v1/auth/me", headers=bob_headers)).json()["data"]["user"]
    assert alice_me["counts"]["connections"] == 1
    assert bob_me["counts"]["followers"] == 1


async def test_unfollowing_reverses_the_counts(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)

    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)
    await client.delete(f"/v1/connections/{bob['username']}", headers=alice_headers)

    bob_me = (await client.get("/v1/auth/me", headers=bob_headers)).json()["data"]["user"]
    assert bob_me["counts"]["followers"] == 0


async def test_you_cannot_follow_yourself(client, alice):
    headers = await auth_headers(client, alice)
    response = await client.post(f"/v1/connections/{alice['username']}", headers=headers)
    assert response.status_code == 400
    assert response.json()["data"]["code"] == "SELF_FOLLOW"


async def test_public_profile_reports_following_state(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    await signup(client, bob)
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    profile = (await client.get(f"/v1/users/{bob['username']}", headers=alice_headers)).json()[
        "data"
    ]["user"]
    assert profile["is_following"] is True
    assert profile["is_me"] is False


async def test_my_own_profile_is_marked(client, alice):
    headers = await auth_headers(client, alice)
    profile = (await client.get(f"/v1/users/{alice['username']}", headers=headers)).json()["data"][
        "user"
    ]
    assert profile["is_me"] is True


async def test_followers_and_following_lists(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    following = (await client.get("/v1/connections/following", headers=alice_headers)).json()[
        "data"
    ]["items"]
    followers = (await client.get("/v1/connections/followers", headers=bob_headers)).json()["data"][
        "items"
    ]

    assert following[0]["username"] == bob["username"]
    assert followers[0]["username"] == alice["username"]


async def test_blocking_removes_the_follow_both_ways(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    await client.post(f"/v1/connections/{alice['username']}/block", headers=bob_headers)

    following = (await client.get("/v1/connections/following", headers=alice_headers)).json()[
        "data"
    ]["items"]
    assert following == []


async def test_a_blocked_users_stories_leave_the_feed(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    story = await publish(client, bob_headers, body="Bob writes something.")

    await client.post(f"/v1/connections/{bob['username']}/block", headers=alice_headers)

    items = (await client.get("/v1/stories/feed", headers=alice_headers)).json()["data"]["items"]
    assert all(item["story_id"] != story["story_id"] for item in items)


async def test_feed_puts_followed_authors_first(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    stranger_headers = await auth_headers(client, account("stranger_w"))

    await publish(client, bob_headers, body="Followed author story.")
    await publish(client, stranger_headers, body="Stranger story published later.")

    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    items = (await client.get("/v1/stories/feed", headers=alice_headers)).json()["data"]["items"]
    assert items[0]["author"]["username"] == bob["username"]
    assert len(items) == 2


async def test_feed_still_includes_everything_after_the_personal_slice(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    stranger_headers = await auth_headers(client, account("stranger2_w"))

    await publish(client, bob_headers, body="From someone I follow.")
    await publish(client, stranger_headers, body="From a stranger.")
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    usernames = [
        item["author"]["username"]
        for item in (await client.get("/v1/stories/feed", headers=alice_headers)).json()["data"][
            "items"
        ]
    ]
    assert usernames == [bob["username"], "stranger2_w"]


async def test_feed_paginates_across_the_phase_boundary(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    stranger_headers = await auth_headers(client, account("stranger3_w"))

    await publish(client, bob_headers, body="Followed one.")
    await publish(client, stranger_headers, body="Stranger one.")
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    first = (await client.get("/v1/stories/feed?limit=1", headers=alice_headers)).json()["data"]
    assert first["has_more"] is True

    second = (
        await client.get(
            f"/v1/stories/feed?limit=1&cursor={first['next_cursor']}",
            headers=alice_headers,
        )
    ).json()["data"]
    assert second["items"][0]["author"]["username"] == "stranger3_w"
    assert second["has_more"] is False


async def test_feed_never_repeats_a_story_across_phases(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    await publish(client, bob_headers, body="Only once please.")
    await client.post(f"/v1/connections/{bob['username']}", headers=alice_headers)

    seen = []
    cursor = None
    for _ in range(4):
        query = f"/v1/stories/feed?limit=1{f'&cursor={cursor}' if cursor else ''}"
        page = (await client.get(query, headers=alice_headers)).json()["data"]
        seen.extend(item["story_id"] for item in page["items"])
        cursor = page["next_cursor"]
        if not page["has_more"]:
            break

    assert len(seen) == len(set(seen))


async def test_joined_community_stories_rank_in_the_personal_slice(client, alice, bob):
    alice_headers = await auth_headers(client, alice)
    bob_headers = await auth_headers(client, bob)
    stranger_headers = await auth_headers(client, account("stranger4_w"))

    slug = (await client.get("/v1/communities", headers=alice_headers)).json()["data"]["items"][0][
        "slug"
    ]
    await client.post(f"/v1/communities/{slug}/join", headers=alice_headers)
    await client.post(f"/v1/communities/{slug}/join", headers=bob_headers)

    await publish(client, bob_headers, body="Inside the room.", community=slug)
    await publish(client, stranger_headers, body="Outside the room, later.")

    items = (await client.get("/v1/stories/feed", headers=alice_headers)).json()["data"]["items"]
    assert items[0]["author"]["username"] == bob["username"]


async def test_feed_reports_when_there_is_nothing_more(client, alice):
    headers = await auth_headers(client, alice)
    page = (await client.get("/v1/stories/feed", headers=headers)).json()["data"]
    assert page["has_more"] is False
    assert page["next_cursor"] is None
