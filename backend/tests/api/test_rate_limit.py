import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.config import get_settings


@pytest_asyncio.fixture
async def limited_client(app_instance):
    get_settings.cache_clear()
    settings = get_settings()
    original = settings.RATE_LIMIT_ENABLED
    object.__setattr__(settings, "RATE_LIMIT_ENABLED", True)

    transport = ASGITransport(app=app_instance)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    object.__setattr__(settings, "RATE_LIMIT_ENABLED", original)
    get_settings.cache_clear()


async def test_signup_is_rate_limited_after_the_declared_attempts(limited_client):
    codes = []
    for index in range(7):
        response = await limited_client.post(
            "/v1/auth/signup",
            json={
                "username": f"ratelimit{index}",
                "password": "a-long-enough-password",
                "tnc_accepted": True,
            },
        )
        codes.append(response.status_code)

    assert 429 in codes


async def test_rate_limited_response_tells_the_client_when_to_retry(limited_client):
    for index in range(7):
        response = await limited_client.post(
            "/v1/auth/signup",
            json={
                "username": f"retryafter{index}",
                "password": "a-long-enough-password",
                "tnc_accepted": True,
            },
        )
        if response.status_code == 429:
            body = response.json()
            assert body["data"]["code"] == "RATE_LIMITED"
            assert body["data"]["retry_after_seconds"] > 0
            return

    pytest.fail("Rate limit never triggered.")
