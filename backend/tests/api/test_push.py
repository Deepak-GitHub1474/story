import asyncio

from app.api.endpoints.notifications import service
from app.api.endpoints.notifications.constants import NOTIFICATIONS, PUSH_TOKENS
from app.core.time import utc_now
from app.db import keys
from app.ports.push import PushOutcome
from app.workers.push import deliver_now, sweep_due

LEASE = 60
TRIES = 5


class FakePush:
    def __init__(self, outcome=None):
        self.batches = []
        self._outcome = outcome

    @property
    def is_available(self):
        return True

    async def send(self, messages):
        self.batches.append(list(messages))
        if self._outcome is not None:
            return self._outcome
        return PushOutcome(delivered=tuple(m.token for m in messages))

    @property
    def messages(self):
        return [m for batch in self.batches for m in batch]


async def a_reader(mongo, user_id="usr_reader", *, wants_push=True):
    await mongo["users"].update_one(
        {"_id": user_id},
        {
            "$set": {
                "username": user_id,
                "username_lower": user_id,
                "referral_code": user_id,
                "display_name": "The Reader",
                "prefs": {"notify_in_app": True, "notify_push": wants_push},
            }
        },
        upsert=True,
    )
    return user_id


async def a_phone(mongo, user_id, token="tok_" + "a" * 40):
    await mongo[PUSH_TOKENS].insert_one(
        {"_id": "psh_1", "token": token, "user_id": user_id, "platform": "android"}
    )
    return token


async def a_writer(mongo, user_id="usr_writer", display_name="Deepak"):
    await mongo["users"].update_one(
        {"_id": user_id},
        {
            "$set": {
                "display_name": display_name,
                "username": "deepak",
                "username_lower": "deepak",
                "referral_code": "deepak",
                "avatar_seed": "a" * 16,
            }
        },
        upsert=True,
    )
    return user_id


async def a_notification(mongo, user_id, **overrides):
    await a_writer(mongo)
    await service.notify(
        mongo=mongo,
        redis=None,
        user_id=user_id,
        actor_id="usr_writer",
        kind=overrides.pop("kind", "story_like"),
        target_kind="story",
        target_id=overrides.pop("target_id", "sto_1"),
        body=overrides.pop("body", "liked your story"),
        **overrides,
    )
    return await mongo[NOTIFICATIONS].find_one({"user_id": user_id})


async def send(mongo, notification_id, push, redis=None):
    return await deliver_now(
        notification_id, mongo=mongo, push=push, redis=redis,
        lease_seconds=LEASE, max_tries=TRIES,
    )


async def test_a_new_notification_is_due_for_push(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)

    doc = await a_notification(mongo, user_id)

    assert doc["push_after"] is not None, "a fresh notification must be queued for push"
    assert doc["push_after"] <= utc_now().replace(tzinfo=doc["push_after"].tzinfo)


async def test_notifications_from_before_push_existed_are_never_swept(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    await mongo[NOTIFICATIONS].insert_one(
        {
            "_id": "not_old",
            "user_id": user_id,
            "kind": "story_like",
            "body": "liked your story",
            "read_at": None,
            "created_at": utc_now(),
        }
    )
    await a_phone(mongo, user_id)
    push = FakePush()

    sent = await sweep_due(
        mongo=mongo, push=push, redis=None, lease_seconds=LEASE, max_tries=TRIES
    )

    assert sent == 0, "rows with no push_after must not flood users on first deploy"
    assert push.messages == []
    untouched = await mongo[NOTIFICATIONS].find_one({"_id": "not_old"})
    assert "push_tries" not in untouched, "the sweep must not even attempt to claim it"


async def test_push_is_off_unless_the_reader_turned_it_on(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo, wants_push=False)
    await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush()

    assert await send(mongo, doc["_id"], push) == 0
    assert push.messages == [], "opt-in means opt-in"


async def test_a_reader_who_opted_in_gets_the_push(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    token = await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush()

    assert await send(mongo, doc["_id"], push) == 1
    message = push.messages[0]
    assert message.token == token
    assert message.title == "Deepak"
    assert message.body == "liked your story"
    assert message.data["notification_id"] == doc["_id"]


async def test_nobody_is_pushed_while_they_are_looking_at_the_app(app_instance):
    mongo, redis = app_instance.state.mongo_db, app_instance.state.redis
    user_id = await a_reader(mongo)
    await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    await redis.set(keys.presence(user_id), "1", ex=60)
    push = FakePush()

    assert await send(mongo, doc["_id"], push, redis) == 0
    assert push.messages == [], "they already saw it arrive in the app"


async def test_a_settled_notification_is_never_pushed_twice(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush()

    await send(mongo, doc["_id"], push)
    await send(mongo, doc["_id"], push)

    assert len(push.messages) == 1
    after = await mongo[NOTIFICATIONS].find_one({"_id": doc["_id"]})
    assert "push_after" not in after
    assert after["pushed_at"] is not None


async def test_two_senders_racing_produce_one_push(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush()

    await asyncio.gather(
        send(mongo, doc["_id"], push), send(mongo, doc["_id"], push)
    )

    assert len(push.messages) == 1, "the claim must be atomic across replicas"


async def test_a_dead_token_is_erased_not_left_behind(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    token = await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush(outcome=PushOutcome(stale=(token,)))

    await send(mongo, doc["_id"], push)

    assert await mongo[PUSH_TOKENS].count_documents({"token": token}) == 0


async def test_a_failed_send_stays_due_so_it_is_retried(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    token = await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush(outcome=PushOutcome(retry=(token,)))

    assert await send(mongo, doc["_id"], push) == 0
    after = await mongo[NOTIFICATIONS].find_one({"_id": doc["_id"]})
    assert after.get("push_after") is not None, "a lost push must come back around"
    assert after.get("pushed_at") is None


async def test_a_notification_that_keeps_failing_is_eventually_dropped(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    token = await a_phone(mongo, user_id)
    doc = await a_notification(mongo, user_id)
    push = FakePush(outcome=PushOutcome(retry=(token,)))

    for _ in range(TRIES + 1):
        await mongo[NOTIFICATIONS].update_one(
            {"_id": doc["_id"]}, {"$set": {"push_after": utc_now()}}
        )
        await send(mongo, doc["_id"], push)

    after = await mongo[NOTIFICATIONS].find_one({"_id": doc["_id"]})
    assert "push_after" not in after, "a permanently broken push must stop retrying"


async def test_a_reader_with_no_phone_registered_is_simply_skipped(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    doc = await a_notification(mongo, user_id)
    push = FakePush()

    assert await send(mongo, doc["_id"], push) == 0
    after = await mongo[NOTIFICATIONS].find_one({"_id": doc["_id"]})
    assert "push_after" not in after, "no device means settled, not retried forever"


async def test_every_phone_the_reader_owns_is_reached(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    await a_phone(mongo, user_id)
    await mongo[PUSH_TOKENS].insert_one(
        {"_id": "psh_2", "token": "tok_" + "b" * 40, "user_id": user_id, "platform": "android"}
    )
    doc = await a_notification(mongo, user_id)
    push = FakePush()

    assert await send(mongo, doc["_id"], push) == 2


async def test_collapsed_events_push_once_not_once_per_actor(app_instance):
    mongo = app_instance.state.mongo_db
    user_id = await a_reader(mongo)
    await a_phone(mongo, user_id)

    for _ in range(3):
        await a_notification(mongo, user_id, kind="new_follower", collapse=True)

    rows = await mongo[NOTIFICATIONS].find({"user_id": user_id}).to_list(length=10)
    assert len(rows) == 1, "collapse keeps one row, so it can only be one push"

    push = FakePush()
    assert await send(mongo, rows[0]["_id"], push) == 1
