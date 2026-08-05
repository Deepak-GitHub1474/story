import os
import secrets

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

os.environ.setdefault("API_ENV", "local")
os.environ.setdefault("MONGODB_DB_NAME", "story_test")
os.environ.setdefault("REDIS_URL", "redis://127.0.0.1:6379/15")
os.environ.setdefault("RATE_LIMIT_ENABLED", "false")


@pytest_asyncio.fixture
async def app_instance():
    from app.main import app

    async with app.router.lifespan_context(app):
        yield app


@pytest_asyncio.fixture
async def client(app_instance):
    transport = ASGITransport(app=app_instance)
    async with AsyncClient(transport=transport, base_url="http://test") as http_client:
        yield http_client


REFERENCE_COLLECTIONS = {"interests", "community_categories"}


@pytest_asyncio.fixture(autouse=True)
async def clean_state(app_instance):
    from app.db.seed import seed_reference_data

    db = app_instance.state.mongo_db
    redis = app_instance.state.redis
    for name in await db.list_collection_names():
        if name not in REFERENCE_COLLECTIONS:
            await db[name].delete_many({})
    await seed_reference_data(db)
    await redis.flushdb()
    yield


@pytest.fixture
def unique_username():
    return f"u{secrets.token_hex(4)}"


@pytest.fixture
def signup_payload(unique_username):
    return {
        "username": unique_username,
        "password": "a-long-enough-password",
        "tnc_accepted": True,
    }
