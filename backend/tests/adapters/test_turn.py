"""Credentials a public APK may carry, because they expire before they are worth stealing."""

import base64
import hashlib
import hmac
from datetime import timedelta

from app.adapters.turn import ice_servers
from app.config import Settings
from app.core.time import utc_now

SECRET = "a-test-turn-secret"


def settings() -> Settings:
    return Settings(
        TURN_SHARED_SECRET=SECRET,
        TURN_URLS="turn:relay.example.org:3478,turns:relay.example.org:443?transport=tcp",
        TURN_CREDENTIAL_TTL_SECONDS=300,
    )


def a_relay(servers):
    return [server for server in servers if server["urls"][0].startswith("turn")][0]


def test_the_username_carries_its_own_expiry():
    now = utc_now()

    servers = ice_servers("usr_alice", settings=settings(), now=now)

    expiry, user_id = a_relay(servers)["username"].split(":", 1)
    assert user_id == "usr_alice"
    assert int(expiry) == int((now + timedelta(seconds=300)).timestamp())


def test_the_password_is_an_hmac_of_the_username():
    relay = a_relay(ice_servers("usr_alice", settings=settings()))

    expected = base64.b64encode(
        hmac.new(SECRET.encode(), relay["username"].encode(), hashlib.sha1).digest()
    ).decode()
    assert relay["credential"] == expected


def test_every_configured_relay_url_is_offered():
    relay = a_relay(ice_servers("usr_alice", settings=settings()))

    assert relay["urls"] == [
        "turn:relay.example.org:3478",
        "turns:relay.example.org:443?transport=tcp",
    ]


def test_a_stun_server_is_always_offered_so_most_calls_never_relay():
    servers = ice_servers("usr_alice", settings=settings())

    assert any(server["urls"][0].startswith("stun:") for server in servers)


def test_no_relay_is_offered_when_none_is_configured():
    bare = Settings(TURN_SHARED_SECRET="", TURN_URLS="")

    servers = ice_servers("usr_alice", settings=bare)

    assert all(server["urls"][0].startswith("stun:") for server in servers)


def test_two_people_never_share_a_credential():
    config = settings()

    alice = a_relay(ice_servers("usr_alice", settings=config))["credential"]
    bob = a_relay(ice_servers("usr_bob", settings=config))["credential"]

    assert alice != bob
