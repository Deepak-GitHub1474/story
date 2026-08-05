async def test_health_reports_the_service(client):
    response = await client.get("/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["env"] == "local"


async def test_health_uses_the_standard_envelope(client):
    body = (await client.get("/v1/health")).json()
    assert set(body.keys()) == {"success", "message", "data"}


async def test_ready_probes_mongodb_and_redis_for_real(client):
    response = await client.get("/v1/health/ready")
    assert response.status_code == 200
    assert response.json()["data"] == {"mongodb": True, "redis": True}


async def test_every_response_carries_a_request_id(client):
    response = await client.get("/v1/health")
    assert response.headers["x-request-id"].startswith("req_")


async def test_security_headers_are_present(client):
    headers = (await client.get("/v1/health")).headers
    assert headers["x-content-type-options"] == "nosniff"
    assert headers["referrer-policy"] == "no-referrer"


async def test_unknown_route_returns_the_standard_envelope(client):
    response = await client.get("/v1/does-not-exist")
    assert response.status_code == 404
    body = response.json()
    assert body["success"] is False
    assert body["data"]["code"]
