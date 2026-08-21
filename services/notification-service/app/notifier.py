import logging

logger = logging.getLogger("notification-service")


# Stand-in for a real email/SMS provider (SES/SendGrid/Twilio). Kept as a
# pure, side-effect-logged function so the dedup logic in consumer.py is
# unit-testable without hitting a real provider.
def send_notification(user_id: str, channel: str, message: str) -> None:
    logger.info("notification_sent", extra={"user_id": user_id, "channel": channel, "message": message})
