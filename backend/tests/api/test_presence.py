import base64


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
        "/v1/chat/identity", json={"public_key": b64(bytes([1] * 32))}, headers=headers
    )
    return headers


async def mutual(client, first, second):
    one = await with_identity(client, first)
    two = await with_identity(client, second)
    await client.post(f"/v1/connections/{second}", headers=one)
    await client.post(f"/v1/connections/{first}", headers=two)
    return one, two


async def open_chat(client, headers, username):
    return (
        await client.post(
            "/v1/chat/conversations",
            json={
                "username": username,
                "wrapped_cek_for_me": b64(b"nonce12bytes" + b"for-me"),
                "wrapped_cek_for_them": b64(b"nonce12bytes" + b"for-them"),
                "sender_public_key": b64(bytes([2] * 32)),
            },
            headers=headers,
        )
    ).json()["data"]["conversation"]["conversation_id"]


async def test_a_heartbeat_marks_you_online(client):
    headers = await with_identity(client, "pres_one")

    response = await client.post("/v1/chat/presence", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["online"] is True


async def test_a_peer_who_beat_recently_shows_online(client):
    one, two = await mutual(client, "pres_ann", "pres_ben")
    cid = await open_chat(client, one, "pres_ben")
    await client.post("/v1/chat/presence", headers=two)

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_online"] is True


async def test_a_peer_who_never_beat_is_not_online(client):
    one, _ = await mutual(client, "pres_ann2", "pres_ben2")
    cid = await open_chat(client, one, "pres_ben2")

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_online"] is False


async def test_hiding_your_status_hides_it_from_them(client):
    one, two = await mutual(client, "hide_ann", "hide_ben")
    cid = await open_chat(client, one, "hide_ben")
    await client.post("/v1/chat/presence", headers=two)
    await client.patch(
        "/v1/users/me", json={"prefs": {"show_online_status": False}}, headers=two
    )

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_online"] is None


async def test_hiding_your_status_also_hides_theirs_from_you(client):
    one, two = await mutual(client, "recip_ann", "recip_ben")
    cid = await open_chat(client, one, "recip_ben")
    await client.post("/v1/chat/presence", headers=two)
    await client.patch(
        "/v1/users/me", json={"prefs": {"show_online_status": False}}, headers=one
    )

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_online"] is None


async def test_typing_shows_to_the_other_person(client):
    one, two = await mutual(client, "typ_ann", "typ_ben")
    cid = await open_chat(client, one, "typ_ben")

    await client.post(f"/v1/chat/conversations/{cid}/typing", headers=two)

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_typing"] is True


async def test_your_own_typing_does_not_show_to_you(client):
    one, _ = await mutual(client, "typ_ann2", "typ_ben2")
    cid = await open_chat(client, one, "typ_ben2")

    await client.post(f"/v1/chat/conversations/{cid}/typing", headers=one)

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_typing"] is False


async def test_a_stranger_cannot_announce_typing(client):
    one, _ = await mutual(client, "typ_ann3", "typ_ben3")
    cid = await open_chat(client, one, "typ_ben3")

    stranger = await with_identity(client, "typ_snoop")
    response = await client.post(f"/v1/chat/conversations/{cid}/typing", headers=stranger)

    assert response.status_code == 404


async def test_hiding_your_status_still_lets_typing_through(client):
    one, two = await mutual(client, "typh_ann", "typh_ben")
    cid = await open_chat(client, one, "typh_ben")
    await client.patch(
        "/v1/users/me", json={"prefs": {"show_online_status": False}}, headers=two
    )

    await client.post(f"/v1/chat/conversations/{cid}/typing", headers=two)

    conversation = (
        await client.get(f"/v1/chat/conversations/{cid}", headers=one)
    ).json()["data"]["conversation"]

    assert conversation["other_typing"] is True


async def test_online_status_defaults_to_shown(client):
    headers = await with_identity(client, "default_pres")

    me = (await client.get("/v1/auth/me", headers=headers)).json()["data"]["user"]

    assert me["prefs"].get("show_online_status", True) is True
