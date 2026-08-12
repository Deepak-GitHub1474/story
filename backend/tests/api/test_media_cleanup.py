from tests.api.test_story_images import auth_headers, upload

STORY = {"body": "A long enough story to keep, with a picture attached to it."}


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def a_picture(client, headers):
    return (await upload(client, headers)).json()["data"]["url"]


async def a_story(client, headers, images):
    response = await client.post(
        "/v1/stories", json={**STORY, "images": images}, headers=headers
    )
    return response.json()["data"]["story"]["story_id"]


async def is_stored(client, url):
    return (await client.get(url)).status_code == 200


async def test_deleting_a_story_erases_its_pictures(client):
    headers = await auth_headers(client, account("media_clean_a"))
    picture = await a_picture(client, headers)
    story_id = await a_story(client, headers, [picture])

    assert await is_stored(client, picture)

    await client.delete(f"/v1/stories/{story_id}", headers=headers)

    assert not await is_stored(client, picture)


async def test_a_picture_taken_out_of_a_story_is_erased(client):
    headers = await auth_headers(client, account("media_clean_b"))
    kept = await a_picture(client, headers)
    removed = await a_picture(client, headers)
    story_id = await a_story(client, headers, [kept, removed])

    await client.patch(
        f"/v1/stories/{story_id}", json={"images": [kept]}, headers=headers
    )

    assert await is_stored(client, kept)
    assert not await is_stored(client, removed)


async def test_a_picture_two_stories_share_survives_one_of_them_going(client):
    headers = await auth_headers(client, account("media_clean_c"))
    picture = await a_picture(client, headers)
    first = await a_story(client, headers, [picture])
    await a_story(client, headers, [picture])

    await client.delete(f"/v1/stories/{first}", headers=headers)

    assert await is_stored(client, picture)


async def test_a_story_with_no_pictures_deletes_cleanly(client):
    headers = await auth_headers(client, account("media_clean_d"))
    story_id = await a_story(client, headers, [])

    response = await client.delete(f"/v1/stories/{story_id}", headers=headers)

    assert response.status_code == 200


async def test_only_a_real_media_id_can_ever_reach_storage():
    from app.api.endpoints.media.cleanup import key_for

    assert key_for("/v1/media/med_01HZY8QJ5K7N2M4P6R8T0V2W4X") == (
        "media/med_01HZY8QJ5K7N2M4P6R8T0V2W4X"
    )
    assert key_for("/v1/media/../../../etc/passwd") is None
    assert key_for("/v1/media/vault%2Fsomeone-elses-file") is None
    assert key_for("") is None


async def test_a_story_carrying_a_bad_url_deletes_nothing(app_instance):
    from app.api.endpoints.media.cleanup import drop_unused

    erased = []

    class Watching:
        async def delete(self, *, profile, key):
            erased.append(key)

    removed = await drop_unused(
        ["../../secrets", "/v1/media/not-a-media-id", "/etc/passwd"],
        mongo=app_instance.state.mongo_db,
        storage=Watching(),
    )

    assert removed == 0
    assert erased == []
