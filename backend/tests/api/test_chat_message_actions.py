from datetime import timedelta

from app.api.endpoints.chat import constants as c
from app.core.time import utc_now


async def account(client, name):
    payload = {"username": name, "password": "another-long-password", "tnc_accepted": True}
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def talking(client, app_instance):
    mine = await account(client, "editor_one")
    theirs = await account(client, "editor_two")

    me = (await client.get("/v1/auth/me", headers=mine)).json()["data"]["user"]
    them = (await client.get("/v1/auth/me", headers=theirs)).json()["data"]["user"]

    mongo = app_instance.state.mongo_db
    await mongo[c.CONVERSATIONS].insert_one(
        {
            "_id": "cnv_edit",
            "participant_ids": [me["user_id"], them["user_id"]],
            "state": c.ACCEPTED,
            "requested_by": me["user_id"],
            "deleted_by": [],
            "created_at": utc_now(),
            "updated_at": utc_now(),
        }
    )
    return mine, theirs, me, them


async def a_message(app_instance, sender_id, message_id="msg_1", created_at=None):
    await app_instance.state.mongo_db[c.MESSAGES].insert_one(
        {
            "_id": message_id,
            "conversation_id": "cnv_edit",
            "sender_id": sender_id,
            "ciphertext": "original",
            "reply_to": None,
            "deleted_at": None,
            "reactions": {},
            "created_at": created_at or utc_now(),
        }
    )


async def test_you_can_edit_your_own_message(client, app_instance):
    mine, _, me, _ = await talking(client, app_instance)
    await a_message(app_instance, me["user_id"])

    response = await client.patch(
        "/v1/chat/conversations/cnv_edit/messages/msg_1",
        json={"ciphertext": "reworded"},
        headers=mine,
    )

    assert response.status_code == 200
    assert response.json()["data"]["message"]["ciphertext"] == "reworded"
    assert response.json()["data"]["message"]["edited_at"] is not None


async def test_you_cannot_edit_what_somebody_else_wrote(client, app_instance):
    _, theirs, me, _ = await talking(client, app_instance)
    await a_message(app_instance, me["user_id"])

    response = await client.patch(
        "/v1/chat/conversations/cnv_edit/messages/msg_1",
        json={"ciphertext": "not yours"},
        headers=theirs,
    )

    assert response.status_code == 403


async def test_the_edit_window_closes(client, app_instance):
    mine, _, me, _ = await talking(client, app_instance)
    stale = utc_now() - timedelta(seconds=c.EDIT_WINDOW_SECONDS + 60)
    await a_message(app_instance, me["user_id"], created_at=stale)

    response = await client.patch(
        "/v1/chat/conversations/cnv_edit/messages/msg_1",
        json={"ciphertext": "too late"},
        headers=mine,
    )

    assert response.status_code == 409


async def test_deleting_for_yourself_leaves_it_for_them(client, app_instance):
    mine, theirs, me, _ = await talking(client, app_instance)
    await a_message(app_instance, me["user_id"])

    gone = await client.delete(
        "/v1/chat/conversations/cnv_edit/messages/msg_1/mine", headers=mine
    )
    assert gone.status_code == 200

    ours = await client.get("/v1/chat/conversations/cnv_edit/messages", headers=mine)
    assert ours.json()["data"]["items"] == []

    still = await client.get("/v1/chat/conversations/cnv_edit/messages", headers=theirs)
    assert len(still.json()["data"]["items"]) == 1


async def test_deleting_a_chat_does_not_bring_the_messages_back(client, app_instance):
    mine, _, me, them = await talking(client, app_instance)
    await a_message(app_instance, me["user_id"])

    await client.delete("/v1/chat/conversations/cnv_edit", headers=mine)

    await app_instance.state.mongo_db[c.CONVERSATIONS].update_one(
        {"_id": "cnv_edit"}, {"$pull": {"deleted_by": me["user_id"]}}
    )

    left = await client.get("/v1/chat/conversations/cnv_edit/messages", headers=mine)
    assert left.json()["data"]["items"] == [], (
        "deleting a chat must not be undone by the thread reopening"
    )

    theirs_headers = await account(client, "editor_three")
    assert theirs_headers is not None
