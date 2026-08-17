from datetime import timedelta

from app.api.endpoints.media.cleanup import MEDIA, sweep_orphans
from app.config import get_settings
from app.core.time import utc_now
from app.ports.factory import build_storage
from tests.api.test_media_cleanup import a_story, is_stored
from tests.api.test_story_images import auth_headers, upload

GRACE = 86400


def account(name):
    return {"username": name, "password": "another-long-password", "tnc_accepted": True}


async def a_picture(client, headers):
    body = (await upload(client, headers)).json()["data"]
    return body["media_id"], body["url"]


async def age(mongo, media_id, seconds):
    await mongo[MEDIA].update_one(
        {"_id": media_id},
        {"$set": {"created_at": utc_now() - timedelta(seconds=seconds)}},
    )


async def sweep(mongo):
    return await sweep_orphans(
        mongo=mongo,
        storage=build_storage(get_settings()),
        grace_seconds=GRACE,
    )


async def test_an_upload_is_written_down_so_it_can_be_found_again(
    client, app_instance
):
    headers = await auth_headers(client, account("media_orphan_a"))
    media_id, _ = await a_picture(client, headers)

    noted = await app_instance.state.mongo_db[MEDIA].find_one({"_id": media_id})

    assert noted is not None
    assert noted["created_at"] is not None


async def test_a_picture_no_story_ever_used_is_erased_once_its_grace_is_up(
    client, app_instance
):
    mongo = app_instance.state.mongo_db
    headers = await auth_headers(client, account("media_orphan_b"))
    media_id, url = await a_picture(client, headers)

    assert await is_stored(client, url)

    await age(mongo, media_id, GRACE + 60)
    removed = await sweep(mongo)

    assert removed >= 1
    assert not await is_stored(client, url)
    assert await mongo[MEDIA].find_one({"_id": media_id}) is None


async def test_a_picture_still_being_written_with_is_left_alone(client, app_instance):
    mongo = app_instance.state.mongo_db
    headers = await auth_headers(client, account("media_orphan_c"))
    _, url = await a_picture(client, headers)

    await sweep(mongo)

    assert await is_stored(client, url), "the grace period has not run out yet"


async def test_a_picture_a_draft_holds_survives_the_sweep(client, app_instance):
    mongo = app_instance.state.mongo_db
    headers = await auth_headers(client, account("media_orphan_d"))
    media_id, url = await a_picture(client, headers)
    await a_story(client, headers, [url])

    await age(mongo, media_id, GRACE + 60)
    await sweep(mongo)

    assert await is_stored(client, url), "an unpublished draft still owns its picture"


async def test_taking_a_picture_out_of_a_story_forgets_it_as_well(
    client, app_instance
):
    mongo = app_instance.state.mongo_db
    headers = await auth_headers(client, account("media_orphan_e"))
    media_id, url = await a_picture(client, headers)
    story_id = await a_story(client, headers, [url])

    await client.patch(f"/v1/stories/{story_id}", json={"images": []}, headers=headers)

    assert not await is_stored(client, url)
    assert await mongo[MEDIA].find_one({"_id": media_id}) is None, (
        "the note must go with the bytes, or the sweep chases a ghost forever"
    )


async def test_a_sweep_with_nothing_to_do_costs_nothing(client, app_instance):
    mongo = app_instance.state.mongo_db
    headers = await auth_headers(client, account("media_orphan_f"))
    _, url = await a_picture(client, headers)

    assert await sweep(mongo) == 0
    assert await is_stored(client, url)
