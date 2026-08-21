import fakeredis
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.redis_client import get_redis

# Swap the real Redis dependency for an in-memory fake so unit tests don't
# need a live Redis instance - CI runs this in seconds with no services.
fake = fakeredis.FakeRedis(decode_responses=True)
app.dependency_overrides[get_redis] = lambda: fake

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_fake_redis():
    fake.flushall()
    yield


def test_empty_cart_returns_no_items():
    resp = client.get("/cart/user-1")
    assert resp.status_code == 200
    assert resp.json()["items"] == []


def test_add_item_then_get_cart():
    client.post("/cart/user-1/items", json={
        "product_id": "p1", "name": "Mouse", "price_cents": 1999, "quantity": 2
    })
    resp = client.get("/cart/user-1")
    body = resp.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["quantity"] == 2


def test_remove_item():
    client.post("/cart/user-2/items", json={
        "product_id": "p1", "name": "Mouse", "price_cents": 1999, "quantity": 1
    })
    resp = client.delete("/cart/user-2/items/p1")
    assert resp.status_code == 200
    assert resp.json()["items"] == []
