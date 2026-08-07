async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def tokens_for(client, payload):
    return (await signup(client, payload)).json()["data"]["tokens"]


async def test_a_signed_in_person_can_get_a_socket_ticket(client, signup_payload):
    tokens = await tokens_for(client, signup_payload)
    headers = {"authorization": f"Bearer {tokens['access_token']}"}

    response = await client.post("/v1/realtime/ticket", headers=headers)

    assert response.status_code == 201
    assert len(response.json()["data"]["ticket"]) >= 32


async def test_a_stranger_gets_no_ticket(client):
    response = await client.post("/v1/realtime/ticket")

    assert response.status_code == 401


async def test_the_ticket_is_not_the_access_token(client, signup_payload):
    tokens = await tokens_for(client, signup_payload)
    headers = {"authorization": f"Bearer {tokens['access_token']}"}

    ticket = (await client.post("/v1/realtime/ticket", headers=headers)).json()["data"][
        "ticket"
    ]

    assert ticket not in tokens["access_token"]
    assert tokens["access_token"] not in ticket


async def test_a_ticket_opens_the_socket_once_and_never_again(
    client, signup_payload, app_instance
):
    from app.api.endpoints.realtime import controllers

    tokens = await tokens_for(client, signup_payload)
    headers = {"authorization": f"Bearer {tokens['access_token']}"}
    redis = app_instance.state.redis

    ticket = (await client.post("/v1/realtime/ticket", headers=headers)).json()["data"][
        "ticket"
    ]

    first = await controllers.claim_ticket(ticket, redis=redis)
    second = await controllers.claim_ticket(ticket, redis=redis)

    assert first is not None
    assert second is None


async def test_a_made_up_ticket_opens_nothing(client, app_instance):
    from app.api.endpoints.realtime import controllers

    claimed = await controllers.claim_ticket(
        "not-a-real-ticket", redis=app_instance.state.redis
    )

    assert claimed is None


async def test_an_access_token_is_not_a_ticket(client, signup_payload, app_instance):
    from app.api.endpoints.realtime import controllers

    tokens = await tokens_for(client, signup_payload)

    claimed = await controllers.claim_ticket(
        tokens["access_token"], redis=app_instance.state.redis
    )

    assert claimed is None


async def test_the_ticket_dies_on_its_own_within_a_minute(client, signup_payload, app_instance):
    tokens = await tokens_for(client, signup_payload)
    headers = {"authorization": f"Bearer {tokens['access_token']}"}
    redis = app_instance.state.redis

    ticket = (await client.post("/v1/realtime/ticket", headers=headers)).json()["data"][
        "ticket"
    ]

    from app.api.endpoints.realtime import controllers

    ttl = await redis.ttl(controllers.ticket_key(ticket))

    assert 0 < ttl <= 60


async def test_the_socket_no_longer_takes_a_raw_token(client):
    import inspect

    from app.api.endpoints.realtime import router as realtime_router

    signature = inspect.signature(realtime_router.realtime)

    assert "token" not in signature.parameters
    assert "ticket" in signature.parameters
