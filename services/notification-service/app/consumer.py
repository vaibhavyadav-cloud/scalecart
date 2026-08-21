import asyncio
import json
import logging
import os

from aiokafka import AIOKafkaConsumer

from app.dedup import already_processed
from app.notifier import send_notification
from app.redis_client import get_redis

logger = logging.getLogger("notification-service")

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPICS = ["order.created", "payment.completed", "payment.failed"]

MESSAGES = {
    "order.created": "We've received your order!",
    "payment.completed": "Your payment was successful.",
    "payment.failed": "Your payment could not be processed.",
}


async def consume_forever():
    consumer = AIOKafkaConsumer(
        *TOPICS,
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        # Separate consumer group from payment-service - Kafka fans the
        # same topic out to every distinct group, which is exactly what
        # lets payment-service and notification-service both react to
        # order.created independently without knowing about each other.
        group_id="notification-service-group",
        enable_auto_commit=True,
        auto_offset_reset="latest",
    )
    await consumer.start()
    r = get_redis()
    try:
        async for msg in consumer:
            await handle_message(r, msg.topic, msg.value)
    finally:
        await consumer.stop()


async def handle_message(r, topic: str, raw_value: bytes):
    payload = json.loads(raw_value)
    dedup_key = f"{topic}:{payload.get('orderId') or payload.get('eventId')}"

    if already_processed(r, dedup_key):
        logger.info("skipping duplicate event", extra={"key": dedup_key})
        return

    user_id = payload.get("userId", "unknown")
    send_notification(user_id, "email", MESSAGES.get(topic, "Update on your order."))


def run_in_background_thread():
    """Entry point used by main.py's startup event."""
    asyncio.run(consume_forever())
