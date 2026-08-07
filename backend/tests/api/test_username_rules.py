import pytest


async def signup(client, username):
    return await client.post(
        "/v1/auth/signup",
        json={
            "username": username,
            "password": "a-long-enough-password",
            "tnc_accepted": True,
        },
    )


@pytest.mark.parametrize(
    "username",
    [
        "ab",
        "de",
        "deepak",
        "dev_deepak",
        "dev-deepak",
        "dev__deepak",
        "dev___deepak",
        "a1",
        "x9y8z7",
        "a" * 30,
    ],
)
async def test_a_good_username_is_accepted(client, username):
    assert (await signup(client, username)).status_code == 201


@pytest.mark.parametrize(
    "username",
    [
        "a",
        "a" * 31,
        "_deepak",
        "deepak_",
        "-deepak",
        "deepak-",
        "dev--deepak",
        "dev.deepak",
        "dev deepak",
        "dev@deepak",
        "dev/deepak",
        "dev\\deepak",
        "dev+deepak",
        "dev#deepak",
        "café",
    ],
)
async def test_a_bad_username_is_refused(client, username):
    assert (await signup(client, username)).status_code in (400, 422)


async def test_uppercase_is_folded_rather_than_refused(client):
    response = await signup(client, "DevDeepak")

    assert response.status_code == 201
    assert response.json()["data"]["user"]["username"] == "devdeepak"


@pytest.mark.parametrize(
    "username", ["admin", "support", "story", "help", "root", "api", "moderator"]
)
async def test_a_reserved_name_cannot_be_taken(client, username):
    response = await signup(client, username)

    assert response.status_code in (400, 409, 422)


async def test_a_reserved_name_is_refused_case_insensitively(client):
    assert (await signup(client, "ADMIN")).status_code in (400, 409, 422)


async def test_a_name_that_merely_contains_a_reserved_word_is_fine(client):
    assert (await signup(client, "admiral")).status_code == 201


async def test_the_availability_check_agrees_with_signup(client):
    response = await client.post(
        "/v1/auth/username-available", json={"username": "support"}
    )

    assert response.json()["data"]["available"] is False
