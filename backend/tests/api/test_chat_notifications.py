from app.api.endpoints.notifications.constants import NOTIFICATIONS
from tests.api.test_chat import message_body, mutual, start_body


async def a_conversation(client):
    one, two = await mutual(client, "chat_sender", "chat_reader")
    response = await client.post(
        "/v1/chat/conversations",
        json=start_body(username="chat_reader"),
        headers=one,
    )
    return one, two, response.json()["data"]["conversation"]["conversation_id"]


async def chat_rows_for(mongo, headers, client):
    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]
    return await mongo[NOTIFICATIONS].find(
        {"user_id": me["user_id"], "kind": "chat_message"}
    ).to_list(20)


async def test_a_message_gives_the_reader_something_to_be_pushed(
    client, app_instance
):
    one, two, conversation_id = await a_conversation(client)
    mongo = app_instance.state.mongo_db

    await client.post(
        f"/v1/chat/conversations/{conversation_id}/messages",
        json=message_body(),
        headers=one,
    )

    rows = await chat_rows_for(mongo, two, client)
    assert len(rows) == 1, "without a row there is nothing for push to deliver"
    assert rows[0]["kind"] == "chat_message"
    assert rows[0].get("push_after") is not None, "it must be queued for push"


async def test_a_message_push_never_carries_what_was_said(client, app_instance):
    one, two, conversation_id = await a_conversation(client)

    await client.post(
        f"/v1/chat/conversations/{conversation_id}/messages",
        json=message_body(b"meet me at six"),
        headers=one,
    )

    rows = await chat_rows_for(app_instance.state.mongo_db, two, client)
    assert rows[0]["body"] == "New message"
    assert "six" not in str(rows[0]), "the server holds ciphertext and must reveal none of it"


async def test_the_sender_is_not_notified_of_their_own_message(client, app_instance):
    one, two, conversation_id = await a_conversation(client)

    await client.post(
        f"/v1/chat/conversations/{conversation_id}/messages",
        json=message_body(),
        headers=one,
    )

    assert await chat_rows_for(app_instance.state.mongo_db, one, client) == []


async def test_a_flurry_of_messages_is_one_row_not_twenty(client, app_instance):
    one, two, conversation_id = await a_conversation(client)

    for _ in range(5):
        await client.post(
            f"/v1/chat/conversations/{conversation_id}/messages",
            json=message_body(),
            headers=one,
        )

    rows = await chat_rows_for(app_instance.state.mongo_db, two, client)
    assert len(rows) == 1, "collapse keeps one row per conversation"


async def test_messages_stay_out_of_the_activity_feed(client, app_instance):
    one, two, conversation_id = await a_conversation(client)

    await client.post(
        f"/v1/chat/conversations/{conversation_id}/messages",
        json=message_body(),
        headers=one,
    )

    listed = (await client.get("/v1/notifications", headers=two)).json()["data"]
    kinds = [item["kind"] for item in listed["items"]]

    assert "chat_message" not in kinds, (
        "chat already has its own unread badge, so a feed row double-counts it"
    )
    assert await chat_rows_for(app_instance.state.mongo_db, two, client) != [], (
        "the row must exist for push even though the feed hides it"
    )
