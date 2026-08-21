import os
import redis

# Redis is the store for cart-service on purpose: carts are short-lived,
# read/written on nearly every page view, and disposable (losing an
# abandoned cart is not a data-loss incident the way losing an order would
# be) - a perfect fit for an in-memory key-value store with a TTL instead
# of a durable relational table. See docs/03-databases-per-service.md.
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# decode_responses=True so callers work with str, not bytes.
# A connection pool (not a single connection) so this survives being hit
# concurrently by many async request handlers inside one pod.
_pool = redis.ConnectionPool.from_url(REDIS_URL, decode_responses=True, max_connections=50)


def get_redis() -> redis.Redis:
    return redis.Redis(connection_pool=_pool)
