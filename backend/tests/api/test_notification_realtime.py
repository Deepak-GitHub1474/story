from app.api.endpoints.notifications import service
from app.realtime import bus


async def signed_in(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return tokens["access_token"]


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


def spy_on_publish(monkeypatch):
    sent = []

    async def record(redis, user_ids, payload):
        sent.append((user_ids, payload))

    monkeypatch.setattr(bus, "publish", record)
    return sent


async def test_a_new_notification_reaches_the_recipient_immediately(
    app_instance, monkeypatch
):
    sent = spy_on_publish(monkeypatch)

    await service.notify(
        mongo=app_instance.state.mongo_db,
        redis=app_instance.state.redis,
        user_id="usr_reader",
        actor_id="usr_writer",
        actor_snapshot={"display_name": "Someone", "avatar_seed": "a"},
        kind="story_like",
        target_kind="story",
        target_id="sto_1",
        body="liked your story",
    )

    assert sent, "a notification must be published so the badge appears without a refresh"
    targets, payload = sent[0]
    assert targets == ["usr_reader"]
    assert payload["type"] == "notification"


async def test_a_collapsed_notification_also_reaches_the_recipient(
    app_instance, monkeypatch
):
    sent = spy_on_publish(monkeypatch)

    await service.notify(
        mongo=app_instance.state.mongo_db,
        redis=app_instance.state.redis,
        user_id="usr_reader",
        actor_id="usr_writer",
        actor_snapshot={"display_name": "Someone", "avatar_seed": "a"},
        kind="story_like",
        target_kind="story",
        target_id="sto_2",
        body="liked your story",
        collapse=True,
    )

    assert sent
    assert sent[0][1]["type"] == "notification"


async def test_nothing_is_published_when_the_notification_is_suppressed(
    app_instance, monkeypatch
):
    sent = spy_on_publish(monkeypatch)

    await service.notify(
        mongo=app_instance.state.mongo_db,
        redis=app_instance.state.redis,
        user_id="usr_same",
        actor_id="usr_same",
        actor_snapshot={},
        kind="story_like",
        target_kind="story",
        target_id="sto_3",
        body="liked your story",
    )

    assert sent == []


async def test_liking_a_story_notifies_the_author_over_the_socket(
    client, signup_payload, app_instance, monkeypatch
):
    author = await signed_in(client, signup_payload)
    story = (
        await client.post(
            "/v1/stories",
            json={"body": "A story worth reacting to, at length.", "visibility": "public"},
            headers={"authorization": f"Bearer {author}"},
        )
    ).json()["data"]["story"]

    await client.post(
        f"/v1/stories/{story['story_id']}/publish",
        json={"visibility": "public"},
        headers={"authorization": f"Bearer {author}"},
    )

    reader = await signed_in(client, account("reader_socket"))
    sent = spy_on_publish(monkeypatch)

    await client.post(
        f"/v1/stories/{story['story_id']}/like",
        headers={"authorization": f"Bearer {reader}"},
    )

    kinds = [payload["type"] for _, payload in sent]
    assert "notification" in kinds
