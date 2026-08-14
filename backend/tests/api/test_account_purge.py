from datetime import timedelta

from app.core.time import utc_now
from app.workers.deletion import erase_account, purge_deleted_accounts


async def headers_for(client, payload, username: str) -> dict:
    tokens = (await client.post("/v1/auth/signup", json={**payload, "username": username})).json()[
        "data"
    ]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def me(client, headers) -> str:
    return (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]["user_id"]


async def a_public_story(client, headers, title: str = "A story") -> str:
    story = (
        await client.post(
            "/v1/stories",
            json={"title": title, "body": "x" * 80},
            headers=headers,
        )
    ).json()["data"]["story"]
    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers=headers,
    )
    return story["story_id"]


async def test_everything_a_leaver_wrote_leaves_with_them(
    client, signup_payload, app_instance
):
    leaving = await headers_for(client, signup_payload, "walking_away")
    staying = await headers_for(client, signup_payload, "still_here")
    leaver_id = await me(client, leaving)

    mine = await a_public_story(client, leaving)
    theirs = await a_public_story(client, staying, title="Theirs")

    await client.post(f"/v1/stories/{theirs}/like", headers=leaving)
    await client.post(
        f"/v1/stories/{theirs}/comments", json={"body": "I liked this"}, headers=leaving
    )
    await client.post(f"/v1/stories/{mine}/like", headers=staying)

    db = app_instance.state.mongo_db
    await erase_account(leaver_id, mongo=db)

    assert await db["stories"].count_documents({"_id": mine}) == 0
    assert await db["stories"].count_documents({"author_id": leaver_id}) == 0
    assert await db["comments"].count_documents({"author_id": leaver_id}) == 0
    assert await db["reactions"].count_documents({"user_id": leaver_id}) == 0
    assert await db["notifications"].count_documents({"actor_id": leaver_id}) == 0
    assert await db["reactions"].count_documents({"target_id": mine}) == 0


async def test_the_counts_they_leave_behind_are_put_right(
    client, signup_payload, app_instance
):
    leaving = await headers_for(client, signup_payload, "walking_away")
    staying = await headers_for(client, signup_payload, "still_here")
    leaver_id = await me(client, leaving)

    theirs = await a_public_story(client, staying, title="Theirs")
    await client.post(f"/v1/stories/{theirs}/like", headers=leaving)
    await client.post(
        f"/v1/stories/{theirs}/comments", json={"body": "I liked this"}, headers=leaving
    )

    db = app_instance.state.mongo_db
    before = await db["stories"].find_one({"_id": theirs}, {"counts": 1, "likers": 1})
    assert before["counts"]["likes"] == 1
    assert before["counts"]["comments"] == 1
    assert len(before["likers"]) == 1

    await erase_account(leaver_id, mongo=db)

    after = await db["stories"].find_one({"_id": theirs}, {"counts": 1, "likers": 1})
    assert after["counts"]["likes"] == 0, "their like is gone, so the number goes with it"
    assert after["counts"]["comments"] == 0
    assert after.get("likers") == [], "their face must not stay under a story"


async def test_a_leaver_stops_being_someone_you_can_follow(
    client, signup_payload, app_instance
):
    leaving = await headers_for(client, signup_payload, "walking_away")
    await headers_for(client, signup_payload, "still_here")
    leaver_id = await me(client, leaving)

    await client.post("/v1/connections/still_here", headers=leaving)

    db = app_instance.state.mongo_db
    await erase_account(leaver_id, mongo=db)

    assert (
        await db["connections"].count_documents(
            {"$or": [{"follower_id": leaver_id}, {"followee_id": leaver_id}]}
        )
        == 0
    )
    them = await db["users"].find_one({"username_lower": "still_here"}, {"counts": 1})
    assert them["counts"]["followers"] == 0


async def test_nothing_personal_survives_on_the_user_row(
    client, signup_payload, app_instance
):
    leaving = await headers_for(client, signup_payload, "walking_away")
    leaver_id = await me(client, leaving)

    db = app_instance.state.mongo_db
    await erase_account(leaver_id, mongo=db)

    row = await db["users"].find_one({"_id": leaver_id})
    assert row is not None, "the id stays so nothing else dangles"
    assert row["status"] == "deleted"
    assert row["deleted_at"]
    for gone in ("password_hash", "display_name", "avatar_seed", "bio", "interests", "prefs"):
        assert gone not in row, f"{gone} is still on the row"
    assert row["username"] != "walking_away"


async def test_the_sweep_waits_out_the_grace_period(client, signup_payload, app_instance):
    leaving = await headers_for(client, signup_payload, "walking_away")
    leaver_id = await me(client, leaving)
    db = app_instance.state.mongo_db

    await db["users"].update_one(
        {"_id": leaver_id},
        {"$set": {"status": "pending_deletion", "deletes_at": utc_now() + timedelta(days=1)}},
    )
    assert await purge_deleted_accounts(db) == 0, "they still have days to change their mind"

    await db["users"].update_one(
        {"_id": leaver_id},
        {"$set": {"deletes_at": utc_now() - timedelta(minutes=1)}},
    )
    assert await purge_deleted_accounts(db) == 1

    row = await db["users"].find_one({"_id": leaver_id}, {"status": 1})
    assert row["status"] == "deleted"


async def test_a_profile_goes_quiet_the_moment_deletion_is_asked_for(
    client, signup_payload, app_instance
):
    leaving = await headers_for(client, signup_payload, "walking_away")
    staying = await headers_for(client, signup_payload, "still_here")
    leaver_id = await me(client, leaving)

    found = await client.get("/v1/users/walking_away", headers=staying)
    assert found.status_code == 200

    await app_instance.state.mongo_db["users"].update_one(
        {"_id": leaver_id}, {"$set": {"status": "pending_deletion"}}
    )

    hidden = await client.get("/v1/users/walking_away", headers=staying)
    assert hidden.status_code == 404, "asking to be gone should look gone straight away"


async def test_a_leaver_is_not_listed_among_the_likes(client, signup_payload, app_instance):
    writer = await headers_for(client, signup_payload, "the_writer")
    leaving = await headers_for(client, signup_payload, "walking_away")
    leaver_id = await me(client, leaving)

    story_id = await a_public_story(client, writer)
    await client.post(f"/v1/stories/{story_id}/like", headers=leaving)

    await app_instance.state.mongo_db["users"].update_one(
        {"_id": leaver_id}, {"$set": {"status": "pending_deletion"}}
    )

    page = (await client.get(f"/v1/stories/{story_id}/likes", headers=writer)).json()["data"]
    assert page["items"] == []
