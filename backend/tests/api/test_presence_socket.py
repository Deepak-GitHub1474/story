from app.api.endpoints.chat import controllers as chat_controllers
from app.db import keys


async def signed_in(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return tokens["access_token"]


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def test_a_socket_marks_you_online(client, signup_payload, app_instance):
    token = await signed_in(client, signup_payload)
    redis = app_instance.state.redis

    user_id = (
        await client.get("/v1/auth/me", headers={"authorization": f"Bearer {token}"})
    ).json()["data"]["user"]["user_id"]

    await chat_controllers.mark_online(user_id, redis=redis)
    assert await redis.get(keys.presence(user_id)) is not None

    await chat_controllers.mark_offline(user_id, redis=redis)
    assert await redis.get(keys.presence(user_id)) is None


async def test_going_offline_only_clears_your_own_mark(client, signup_payload, app_instance):
    redis = app_instance.state.redis

    await chat_controllers.mark_online("usr_a", redis=redis)
    await chat_controllers.mark_online("usr_b", redis=redis)
    await chat_controllers.mark_offline("usr_a", redis=redis)

    assert await redis.get(keys.presence("usr_a")) is None
    assert await redis.get(keys.presence("usr_b")) is not None


async def test_presence_expires_on_its_own_if_a_socket_dies_badly(app_instance):
    redis = app_instance.state.redis

    await chat_controllers.mark_online("usr_c", redis=redis)
    ttl = await redis.ttl(keys.presence("usr_c"))

    assert 0 < ttl <= 120


async def test_typing_over_the_socket_reaches_the_other_person(client, app_instance):
    from app.api.endpoints.realtime import router as realtime_router

    redis = app_instance.state.redis
    mongo = app_instance.state.mongo_db

    await mongo["chat_conversations"].insert_one(
        {
            "_id": "cnv_socket",
            "pair_key": "usr_x:usr_y",
            "participant_ids": ["usr_x", "usr_y"],
            "state": "accepted",
        }
    )

    await realtime_router._handle(
        '{"type": "typing", "conversation_id": "cnv_socket"}',
        user_id="usr_x",
        redis=redis,
        mongo=mongo,
    )

    assert await redis.get(keys.typing("cnv_socket", "usr_x")) is not None


async def test_typing_in_a_chat_you_are_not_in_does_nothing(client, app_instance):
    from app.api.endpoints.realtime import router as realtime_router

    redis = app_instance.state.redis
    mongo = app_instance.state.mongo_db

    await mongo["chat_conversations"].insert_one(
        {
            "_id": "cnv_private",
            "pair_key": "usr_p:usr_q",
            "participant_ids": ["usr_p", "usr_q"],
            "state": "accepted",
        }
    )

    await realtime_router._handle(
        '{"type": "typing", "conversation_id": "cnv_private"}',
        user_id="usr_stranger",
        redis=redis,
        mongo=mongo,
    )

    assert await redis.get(keys.typing("cnv_private", "usr_stranger")) is None


async def test_rubbish_over_the_socket_is_ignored(client, app_instance):
    from app.api.endpoints.realtime import router as realtime_router

    await realtime_router._handle(
        "not json at all",
        user_id="usr_x",
        redis=app_instance.state.redis,
        mongo=app_instance.state.mongo_db,
    )
