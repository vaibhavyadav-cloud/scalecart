import fakeredis

from app.dedup import already_processed


def test_first_time_event_is_not_a_duplicate():
    r = fakeredis.FakeRedis(decode_responses=True)
    assert already_processed(r, "order.created:order-1") is False


def test_repeated_event_is_flagged_as_duplicate():
    r = fakeredis.FakeRedis(decode_responses=True)
    assert already_processed(r, "order.created:order-1") is False
    assert already_processed(r, "order.created:order-1") is True


def test_distinct_keys_are_independent():
    r = fakeredis.FakeRedis(decode_responses=True)
    already_processed(r, "order.created:order-1")
    assert already_processed(r, "order.created:order-2") is False
