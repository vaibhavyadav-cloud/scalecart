import os
from redis import Redis

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/1")
_client: Redis | None = None


def get_redis() -> Redis:
    global _client
    if _client is None:
        _client = Redis.from_url(REDIS_URL, decode_responses=True)
    return _client
