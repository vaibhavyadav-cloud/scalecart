from redis import Redis

# Every Kafka topic here is at-least-once delivery, so any consumer that
# has a side effect (sending an email) must dedupe itself. Redis SETNX
# with a TTL gives us a cheap distributed "have I seen this key before"
# check that's shared across all replicas of this service - a plain
# in-memory Python set would NOT work once this scales past one pod.
DEDUP_TTL_SECONDS = 24 * 60 * 60


def already_processed(r: Redis, event_key: str) -> bool:
    # SET ... NX returns True only if the key did NOT already exist,
    # i.e. "this is the first time we're seeing it" -> so we negate it.
    was_set = r.set(f"notif:dedup:{event_key}", "1", nx=True, ex=DEDUP_TTL_SECONDS)
    return not bool(was_set)
