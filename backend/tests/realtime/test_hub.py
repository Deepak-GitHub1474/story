import asyncio

import pytest

from app.realtime.hub import Hub


class FakeSocket:
    def __init__(self, fails=False):
        self.sent = []
        self.fails = fails

    async def send_json(self, payload):
        if self.fails:
            raise ConnectionError("gone")
        self.sent.append(payload)


@pytest.fixture
def hub():
    return Hub()


async def test_a_message_reaches_a_connected_user(hub):
    socket = FakeSocket()
    hub.attach("usr_1", socket)

    await hub.deliver("usr_1", {"type": "message", "id": "m1"})

    assert socket.sent == [{"type": "message", "id": "m1"}]


async def test_nothing_is_sent_to_someone_who_is_not_connected(hub):
    socket = FakeSocket()
    hub.attach("usr_1", socket)

    await hub.deliver("usr_2", {"type": "message"})

    assert socket.sent == []


async def test_every_device_of_one_account_receives(hub):
    phone = FakeSocket()
    laptop = FakeSocket()
    hub.attach("usr_1", phone)
    hub.attach("usr_1", laptop)

    await hub.deliver("usr_1", {"type": "message"})

    assert len(phone.sent) == 1
    assert len(laptop.sent) == 1


async def test_detaching_stops_delivery(hub):
    socket = FakeSocket()
    hub.attach("usr_1", socket)
    hub.detach("usr_1", socket)

    await hub.deliver("usr_1", {"type": "message"})

    assert socket.sent == []


async def test_detaching_one_device_leaves_the_other(hub):
    phone = FakeSocket()
    laptop = FakeSocket()
    hub.attach("usr_1", phone)
    hub.attach("usr_1", laptop)

    hub.detach("usr_1", phone)
    await hub.deliver("usr_1", {"type": "message"})

    assert phone.sent == []
    assert len(laptop.sent) == 1


async def test_a_dead_socket_is_dropped_rather_than_breaking_the_send(hub):
    dead = FakeSocket(fails=True)
    alive = FakeSocket()
    hub.attach("usr_1", dead)
    hub.attach("usr_1", alive)

    await hub.deliver("usr_1", {"type": "message"})

    assert len(alive.sent) == 1
    assert hub.count("usr_1") == 1


async def test_the_hub_knows_who_is_online(hub):
    hub.attach("usr_1", FakeSocket())

    assert hub.is_online("usr_1") is True
    assert hub.is_online("usr_2") is False


async def test_a_broadcast_reaches_every_named_user(hub):
    one = FakeSocket()
    two = FakeSocket()
    hub.attach("usr_1", one)
    hub.attach("usr_2", two)

    await hub.broadcast(["usr_1", "usr_2"], {"type": "typing"})

    assert len(one.sent) == 1
    assert len(two.sent) == 1


async def test_a_broadcast_can_skip_the_person_who_caused_it(hub):
    sender = FakeSocket()
    other = FakeSocket()
    hub.attach("usr_1", sender)
    hub.attach("usr_2", other)

    await hub.broadcast(["usr_1", "usr_2"], {"type": "typing"}, skip="usr_1")

    assert sender.sent == []
    assert len(other.sent) == 1


async def test_delivery_to_many_devices_happens_concurrently(hub):
    class SlowSocket(FakeSocket):
        async def send_json(self, payload):
            await asyncio.sleep(0.05)
            self.sent.append(payload)

    for _ in range(10):
        hub.attach("usr_1", SlowSocket())

    start = asyncio.get_running_loop().time()
    await hub.deliver("usr_1", {"type": "message"})
    elapsed = asyncio.get_running_loop().time() - start

    assert elapsed < 0.2, "sends should overlap rather than queue"


async def test_the_last_detach_removes_the_user_entirely(hub):
    socket = FakeSocket()
    hub.attach("usr_1", socket)
    hub.detach("usr_1", socket)

    assert hub.is_online("usr_1") is False
    assert hub.count("usr_1") == 0
