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
