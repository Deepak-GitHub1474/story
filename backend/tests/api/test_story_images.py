import base64
import struct


def jpeg(payload: bytes = b"pixels", exif: bytes = b"GPS 51.5 N") -> bytes:
    exif_segment = b"\xff\xe1" + struct.pack(">H", len(exif) + 8) + b"Exif\x00\x00" + exif
    scan = b"\xff\xda" + struct.pack(">H", len(payload) + 2) + payload
    return b"\xff\xd8" + exif_segment + scan + b"\xff\xd9"


async def auth_headers(client, payload):
    tokens = (await client.post("/v1/auth/signup", json=payload)).json()["data"]["tokens"]
    return {"authorization": f"Bearer {tokens['access_token']}"}


async def upload(client, headers, data=None, kind="image/jpeg"):
    return await client.post(
        "/v1/media/images",
        json={
            "kind": kind,
            "data": base64.b64encode(data if data is not None else jpeg()).decode(),
        },
        headers=headers,
    )


async def test_a_picture_can_be_uploaded(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await upload(client, headers)

    assert response.status_code == 201
    assert response.json()["data"]["url"]


async def test_the_stored_picture_has_no_exif(client, signup_payload, app_instance):
    headers = await auth_headers(client, signup_payload)

    media_id = (await upload(client, headers)).json()["data"]["media_id"]

    from app.config import get_settings
    from app.ports.factory import build_storage

    storage = build_storage(get_settings())
    stored = await storage.read(profile="media", key=f"media/{media_id}")
    assert b"GPS" not in stored


async def test_a_picture_needs_an_account(client):
    response = await client.post(
        "/v1/media/images",
        json={"kind": "image/jpeg", "data": base64.b64encode(jpeg()).decode()},
    )

    assert response.status_code == 401


async def test_a_pdf_pretending_to_be_a_picture_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await upload(client, headers, data=b"%PDF-1.4 not a picture")

    assert response.status_code == 422


async def test_a_kind_we_do_not_take_is_refused(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await upload(client, headers, kind="image/gif")

    assert response.status_code == 422


async def test_a_story_can_carry_pictures(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    url = (await upload(client, headers)).json()["data"]["url"]

    story = (
        await client.post(
            "/v1/stories",
            json={"body": "With a picture.", "images": [url]},
            headers=headers,
        )
    ).json()["data"]["story"]

    assert story["images"] == [url]


async def test_a_story_without_pictures_says_so_plainly(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    story = (
        await client.post("/v1/stories", json={"body": "No picture."}, headers=headers)
    ).json()["data"]["story"]

    assert story["images"] == []


async def test_pictures_survive_into_the_feed(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    url = (await upload(client, headers)).json()["data"]["url"]
    story = (
        await client.post(
            "/v1/stories",
            json={"body": "With a picture.", "images": [url]},
            headers=headers,
        )
    ).json()["data"]["story"]["story_id"]
    await client.post(
        f"/v1/stories/{story}/publish", json={"visibility": "public"}, headers=headers
    )

    mine = (await client.get("/v1/stories/mine", headers=headers)).json()["data"]["items"]

    assert mine[0]["images"] == [url]


async def test_a_made_up_media_id_never_reaches_storage(client, monkeypatch):
    from app.api.endpoints.media import router as media_router

    asked = []

    class Spy:
        async def read(self, *, profile, key):
            asked.append(key)
            return None

    monkeypatch.setattr(media_router, "build_storage", lambda settings: Spy())

    for bad in (
        "not-a-real-id",
        "med_short",
        "%2e%2e%2fvault%2fusr_x",
        "med_01KZDX8B6DR33WZBFHW8F4MNPJ/../../secret",
    ):
        response = await client.get(f"/v1/media/{bad}")
        assert response.status_code == 404

    assert asked == []


async def test_a_real_looking_id_does_reach_storage(client, monkeypatch):
    from app.api.endpoints.media import router as media_router

    asked = []

    class Spy:
        async def read(self, *, profile, key):
            asked.append(key)
            return None

    monkeypatch.setattr(media_router, "build_storage", lambda settings: Spy())

    await client.get("/v1/media/med_01KZDX8B6DR33WZBFHW8F4MNPJ")

    assert asked == ["media/med_01KZDX8B6DR33WZBFHW8F4MNPJ"]


async def test_a_picture_is_served_with_sniffing_turned_off(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    url = (await upload(client, headers)).json()["data"]["url"]

    response = await client.get(url.replace("/v1", ""))

    assert response.headers["x-content-type-options"] == "nosniff"


async def test_a_story_cannot_point_at_someone_elses_server(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.post(
        "/v1/stories",
        json={"body": "Look.", "images": ["https://tracker.example.com/pixel.png"]},
        headers=headers,
    )

    assert response.status_code == 422


async def test_a_story_cannot_point_at_a_made_up_path(client, signup_payload):
    headers = await auth_headers(client, signup_payload)

    response = await client.post(
        "/v1/stories",
        json={"body": "Look.", "images": ["/v1/media/../../etc/passwd"]},
        headers=headers,
    )

    assert response.status_code == 422


async def test_a_story_can_still_point_at_a_real_picture(client, signup_payload):
    headers = await auth_headers(client, signup_payload)
    url = (await upload(client, headers)).json()["data"]["url"]

    response = await client.post(
        "/v1/stories", json={"body": "Look.", "images": [url]}, headers=headers
    )

    assert response.status_code == 201
