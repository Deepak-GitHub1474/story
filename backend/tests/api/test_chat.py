import base64

import pytest


async def signup(client, payload):
    return await client.post("/v1/auth/signup", json=payload)


async def auth_headers(client, payload):
    tokens = (await signup(client, payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


async def with_identity(client, name):
    headers = await auth_headers(client, account(name))
    await client.post(
        "/v1/chat/identity",
        json={"public_key": b64(bytes([1] * 32) + name.encode()[:0])},
        headers=headers,
    )
    return headers


async def follow(client, headers, username):
    return await client.post(f"/v1/connections/{username}", headers=headers)


def start_body(**overrides):
    return {
        "username": "them",
        "wrapped_cek_for_me": b64(b"nonce12bytes" + b"wrapped-for-me"),
        "wrapped_cek_for_them": b64(b"nonce12bytes" + b"wrapped-for-them"),
        "sender_public_key": b64(bytes([2] * 32)),
        **overrides,
    }


def message_body(text=b"ciphertext-here"):
    return {"ciphertext": b64(b"nonce12bytes" + text)}


@pytest.fixture
def pair():
    return ("chat_ann", "chat_ben")


async def mutual(client, first, second):
    one = await with_identity(client, first)
    two = await with_identity(client, second)
    await follow(client, one, second)
    await follow(client, two, first)
    return one, two


async def test_a_public_key_can_be_published_and_read_back(client):
    headers = await with_identity(client, "key_owner")

    mine = await client.get("/v1/chat/identity", headers=headers)

    assert mine.status_code == 200
    assert mine.json()["data"]["public_key"]


async def test_another_users_public_key_is_readable(client):
    await with_identity(client, "key_holder")
    reader = await with_identity(client, "key_reader")

    response = await client.get("/v1/chat/identity/key_holder", headers=reader)

    assert response.status_code == 200
    assert response.json()["data"]["public_key"]


async def test_two_people_who_follow_each_other_get_an_open_conversation(client, pair):
    one, _ = await mutual(client, *pair)

    response = await client.post(
        "/v1/chat/conversations", json=start_body(username=pair[1]), headers=one
    )

    assert response.status_code == 201
    assert response.json()["data"]["conversation"]["state"] == "accepted"


async def test_a_one_sided_follow_becomes_a_request(client):
    one = await with_identity(client, "req_sender")
    await with_identity(client, "req_target")
    await follow(client, one, "req_target")

    response = await client.post(
        "/v1/chat/conversations", json=start_body(username="req_target"), headers=one
    )

    assert response.status_code == 201
    assert response.json()["data"]["conversation"]["state"] == "pending"


async def test_a_request_sits_in_the_recipients_requests_not_their_inbox(client):
    one = await with_identity(client, "req_sender2")
    two = await with_identity(client, "req_target2")
    await follow(client, one, "req_target2")
    await client.post(
        "/v1/chat/conversations", json=start_body(username="req_target2"), headers=one
    )

    inbox = (await client.get("/v1/chat/conversations", headers=two)).json()["data"]
    requests = (
        await client.get("/v1/chat/conversations?state=pending", headers=two)
    ).json()["data"]

    assert inbox["items"] == []
    assert len(requests["items"]) == 1


async def test_the_sender_sees_their_own_request_in_their_inbox(client):
    one = await with_identity(client, "req_sender3")
    await with_identity(client, "req_target3")
    await follow(client, one, "req_target3")
    await client.post(
        "/v1/chat/conversations", json=start_body(username="req_target3"), headers=one
    )

    inbox = (await client.get("/v1/chat/conversations", headers=one)).json()["data"]

    assert len(inbox["items"]) == 1


async def test_accepting_a_request_opens_the_conversation(client):
    one = await with_identity(client, "acc_sender")
    two = await with_identity(client, "acc_target")
    await follow(client, one, "acc_target")
    conversation = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="acc_target"), headers=one
        )
    ).json()["data"]["conversation"]

    accepted = await client.post(
        f"/v1/chat/conversations/{conversation['conversation_id']}/accept", headers=two
    )

    assert accepted.status_code == 200
    inbox = (await client.get("/v1/chat/conversations", headers=two)).json()["data"]
    assert len(inbox["items"]) == 1


async def test_only_the_recipient_can_accept(client):
    one = await with_identity(client, "acc_sender2")
    await with_identity(client, "acc_target2")
    await follow(client, one, "acc_target2")
    conversation = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="acc_target2"), headers=one
        )
    ).json()["data"]["conversation"]

    response = await client.post(
        f"/v1/chat/conversations/{conversation['conversation_id']}/accept", headers=one
    )

    assert response.status_code == 403


async def test_starting_the_same_conversation_twice_returns_the_first_one(client, pair):
    one, _ = await mutual(client, "dup_ann", "dup_ben")

    first = await client.post(
        "/v1/chat/conversations", json=start_body(username="dup_ben"), headers=one
    )
    second = await client.post(
        "/v1/chat/conversations", json=start_body(username="dup_ben"), headers=one
    )

    assert second.status_code == 200
    assert (
        second.json()["data"]["conversation"]["conversation_id"]
        == first.json()["data"]["conversation"]["conversation_id"]
    )


async def test_you_cannot_open_a_conversation_with_yourself(client):
    headers = await with_identity(client, "lonely_one")

    response = await client.post(
        "/v1/chat/conversations", json=start_body(username="lonely_one"), headers=headers
    )

    assert response.status_code == 422


async def test_a_blocked_person_cannot_reach_you(client):
    one = await with_identity(client, "blk_sender")
    two = await with_identity(client, "blk_target")
    await client.post("/v1/connections/blk_sender/block", headers=two)

    response = await client.post(
        "/v1/chat/conversations", json=start_body(username="blk_target"), headers=one
    )

    assert response.status_code == 403


async def test_a_message_round_trips_as_ciphertext(client):
    one, two = await mutual(client, "msg_ann", "msg_ben")
    conversation = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="msg_ben"), headers=one
        )
    ).json()["data"]["conversation"]
    cid = conversation["conversation_id"]

    sent = await client.post(
        f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
    )
    assert sent.status_code == 201

    theirs = (
        await client.get(f"/v1/chat/conversations/{cid}/messages", headers=two)
    ).json()["data"]["items"]

    assert len(theirs) == 1
    assert theirs[0]["ciphertext"] == message_body()["ciphertext"]


async def test_the_server_never_stores_anything_readable(client, app_instance):
    one, _ = await mutual(client, "opaque_ann", "opaque_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="opaque_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    await client.post(
        f"/v1/chat/conversations/{cid}/messages",
        json={"ciphertext": b64(b"nonce12bytes" + b"hello there")},
        headers=one,
    )

    stored = await app_instance.state.mongo_db["chat_messages"].find_one({})

    assert "hello there" not in str(stored)
    assert "body" not in stored
    assert "text" not in stored


async def test_a_stranger_cannot_read_a_conversation(client):
    one, _ = await mutual(client, "priv_ann", "priv_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="priv_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    await client.post(
        f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
    )

    stranger = await with_identity(client, "priv_snoop")
    response = await client.get(f"/v1/chat/conversations/{cid}/messages", headers=stranger)

    assert response.status_code == 404


async def test_a_stranger_cannot_send_into_a_conversation(client):
    one, _ = await mutual(client, "send_ann", "send_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="send_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]

    stranger = await with_identity(client, "send_snoop")
    response = await client.post(
        f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=stranger
    )

    assert response.status_code == 404


async def test_each_participant_gets_only_their_own_wrapped_key(client):
    one, two = await mutual(client, "key_ann", "key_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="key_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]

    mine = (await client.get(f"/v1/chat/conversations/{cid}", headers=one)).json()["data"][
        "conversation"
    ]
    theirs = (await client.get(f"/v1/chat/conversations/{cid}", headers=two)).json()["data"][
        "conversation"
    ]

    assert mine["wrapped_cek"] == start_body()["wrapped_cek_for_me"]
    assert theirs["wrapped_cek"] == start_body()["wrapped_cek_for_them"]
    assert mine["wrapped_cek"] != theirs["wrapped_cek"]


async def test_messages_page_backwards_from_newest(client):
    one, _ = await mutual(client, "page_ann", "page_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="page_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]

    for index in range(5):
        await client.post(
            f"/v1/chat/conversations/{cid}/messages",
            json={"ciphertext": b64(b"nonce12bytes" + f"m{index}".encode())},
            headers=one,
        )

    first = (
        await client.get(f"/v1/chat/conversations/{cid}/messages?limit=2", headers=one)
    ).json()["data"]

    assert len(first["items"]) == 2
    assert first["has_more"] is True

    second = (
        await client.get(
            f"/v1/chat/conversations/{cid}/messages?limit=2&cursor={first['next_cursor']}",
            headers=one,
        )
    ).json()["data"]

    ids = {item["message_id"] for item in first["items"]}
    assert not ids & {item["message_id"] for item in second["items"]}


async def test_new_messages_can_be_polled_by_id(client):
    one, two = await mutual(client, "poll_ann", "poll_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="poll_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]

    first = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(b"one"), headers=one
        )
    ).json()["data"]["message"]

    await client.post(
        f"/v1/chat/conversations/{cid}/messages", json=message_body(b"two"), headers=two
    )

    fresh = (
        await client.get(
            f"/v1/chat/conversations/{cid}/messages?after={first['message_id']}", headers=one
        )
    ).json()["data"]["items"]

    assert len(fresh) == 1


async def test_reading_a_conversation_clears_its_unread_count(client):
    one, two = await mutual(client, "read_ann", "read_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="read_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    sent = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )
    ).json()["data"]["message"]

    before = (await client.get("/v1/chat/conversations", headers=two)).json()["data"]["items"]
    assert before[0]["unread_count"] == 1

    await client.post(
        f"/v1/chat/conversations/{cid}/read",
        json={"message_id": sent["message_id"]},
        headers=two,
    )

    after = (await client.get("/v1/chat/conversations", headers=two)).json()["data"]["items"]
    assert after[0]["unread_count"] == 0


async def test_the_sender_can_see_that_it_was_read(client):
    one, two = await mutual(client, "seen_ann", "seen_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="seen_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    sent = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )
    ).json()["data"]["message"]

    await client.post(
        f"/v1/chat/conversations/{cid}/read",
        json={"message_id": sent["message_id"]},
        headers=two,
    )

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["their_last_read_message_id"] == sent["message_id"]


async def test_unsending_replaces_the_message_with_a_tombstone(client):
    one, two = await mutual(client, "uns_ann", "uns_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="uns_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    sent = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )
    ).json()["data"]["message"]

    await client.delete(
        f"/v1/chat/conversations/{cid}/messages/{sent['message_id']}", headers=one
    )

    theirs = (
        await client.get(f"/v1/chat/conversations/{cid}/messages", headers=two)
    ).json()["data"]["items"]

    assert theirs[0]["is_deleted"] is True
    assert theirs[0]["ciphertext"] is None


async def test_you_cannot_unsend_someone_elses_message(client):
    one, two = await mutual(client, "uns2_ann", "uns2_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="uns2_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    sent = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )
    ).json()["data"]["message"]

    response = await client.delete(
        f"/v1/chat/conversations/{cid}/messages/{sent['message_id']}", headers=two
    )

    assert response.status_code == 403


async def test_a_reaction_can_be_added_and_removed(client):
    one, two = await mutual(client, "rct_ann", "rct_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="rct_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    sent = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )
    ).json()["data"]["message"]

    await client.post(
        f"/v1/chat/conversations/{cid}/messages/{sent['message_id']}/reaction",
        json={"emoji": "❤️"},
        headers=two,
    )
    items = (
        await client.get(f"/v1/chat/conversations/{cid}/messages", headers=one)
    ).json()["data"]["items"]
    assert items[0]["reactions"][0]["emoji"] == "❤️"

    await client.delete(
        f"/v1/chat/conversations/{cid}/messages/{sent['message_id']}/reaction", headers=two
    )
    items = (
        await client.get(f"/v1/chat/conversations/{cid}/messages", headers=one)
    ).json()["data"]["items"]
    assert items[0]["reactions"] == []


async def test_a_reply_points_at_the_message_it_answers(client):
    one, _ = await mutual(client, "rep_ann", "rep_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="rep_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    first = (
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )
    ).json()["data"]["message"]

    reply = await client.post(
        f"/v1/chat/conversations/{cid}/messages",
        json={**message_body(b"a reply"), "reply_to": first["message_id"]},
        headers=one,
    )

    assert reply.status_code == 201
    assert reply.json()["data"]["message"]["reply_to"] == first["message_id"]


async def test_conversations_sort_by_most_recent_activity(client):
    one = await with_identity(client, "sort_ann")
    for name in ("sort_ben", "sort_cat"):
        two = await with_identity(client, name)
        await follow(client, one, name)
        await follow(client, two, "sort_ann")
        await client.post(
            "/v1/chat/conversations", json=start_body(username=name), headers=one
        )

    inbox = (await client.get("/v1/chat/conversations", headers=one)).json()["data"]["items"]
    older = inbox[1]["conversation_id"]

    await client.post(
        f"/v1/chat/conversations/{older}/messages", json=message_body(), headers=one
    )

    inbox = (await client.get("/v1/chat/conversations", headers=one)).json()["data"]["items"]
    assert inbox[0]["conversation_id"] == older


async def test_the_unread_total_counts_every_conversation(client):
    one, two = await mutual(client, "tot_ann", "tot_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="tot_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    for _ in range(3):
        await client.post(
            f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
        )

    total = (await client.get("/v1/chat/unread-count", headers=two)).json()["data"]

    assert total["unread"] == 3


async def test_a_pending_request_does_not_count_as_unread(client):
    one = await with_identity(client, "pend_ann")
    two = await with_identity(client, "pend_ben")
    await follow(client, one, "pend_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="pend_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    await client.post(
        f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
    )

    total = (await client.get("/v1/chat/unread-count", headers=two)).json()["data"]

    assert total["unread"] == 0
    assert total["requests"] == 1


async def test_a_conversation_key_can_be_replaced_after_a_reinstall(client):
    one, two = await mutual(client, "rekey_ann", "rekey_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="rekey_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]

    response = await client.put(
        f"/v1/chat/conversations/{cid}/keys",
        json={
            "wrapped_cek_for_me": b64(b"nonce12bytes" + b"fresh-for-me"),
            "wrapped_cek_for_them": b64(b"nonce12bytes" + b"fresh-for-them"),
            "sender_public_key": b64(bytes([9] * 32)),
        },
        headers=one,
    )

    assert response.status_code == 200

    mine = (await client.get(f"/v1/chat/conversations/{cid}", headers=one)).json()["data"][
        "conversation"
    ]
    theirs = (await client.get(f"/v1/chat/conversations/{cid}", headers=two)).json()["data"][
        "conversation"
    ]

    assert mine["wrapped_cek"] == b64(b"nonce12bytes" + b"fresh-for-me")
    assert theirs["wrapped_cek"] == b64(b"nonce12bytes" + b"fresh-for-them")


async def test_rekeying_drops_messages_nobody_can_read_any_more(client):
    one, _ = await mutual(client, "rekey2_ann", "rekey2_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="rekey2_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]
    await client.post(
        f"/v1/chat/conversations/{cid}/messages", json=message_body(), headers=one
    )

    await client.put(
        f"/v1/chat/conversations/{cid}/keys",
        json={
            "wrapped_cek_for_me": b64(b"nonce12bytes" + b"fresh-for-me"),
            "wrapped_cek_for_them": b64(b"nonce12bytes" + b"fresh-for-them"),
            "sender_public_key": b64(bytes([9] * 32)),
        },
        headers=one,
    )

    items = (
        await client.get(f"/v1/chat/conversations/{cid}/messages", headers=one)
    ).json()["data"]["items"]

    assert items == []


async def test_a_stranger_cannot_rekey_your_conversation(client):
    one, _ = await mutual(client, "rekey3_ann", "rekey3_ben")
    cid = (
        await client.post(
            "/v1/chat/conversations", json=start_body(username="rekey3_ben"), headers=one
        )
    ).json()["data"]["conversation"]["conversation_id"]

    stranger = await with_identity(client, "rekey3_snoop")
    response = await client.put(
        f"/v1/chat/conversations/{cid}/keys",
        json={
            "wrapped_cek_for_me": b64(b"nonce12bytes" + b"stolen"),
            "wrapped_cek_for_them": b64(b"nonce12bytes" + b"stolen"),
            "sender_public_key": b64(bytes([9] * 32)),
        },
        headers=stranger,
    )

    assert response.status_code == 404
