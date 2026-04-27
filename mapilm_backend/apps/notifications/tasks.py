import logging

from asgiref.sync import async_to_sync
from celery import shared_task
from channels.layers import get_channel_layer
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()
logger = logging.getLogger(__name__)


# ── Push notification ──────────────────────────────────────────────────────

@shared_task(
    bind=True,
    max_retries=3,
    default_retry_delay=10,
    name='notifications.send_push_notification',
)
def send_push_notification(self, user_id: str, title: str, body: str, data: dict = None):
    """
    Send an FCM push notification to a single user and log it.

    Args:
        user_id: UUID string of the recipient.
        title:   Notification title.
        body:    Notification body text.
        data:    Optional key-value payload dict (all values must be strings).
    """
    from firebase_admin import messaging
    from firebase_admin.exceptions import FirebaseError
    from .models import NotificationLog

    data = data or {}

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        logger.warning('send_push_notification: user %s not found', user_id)
        return

    log = NotificationLog.objects.create(
        recipient=user,
        title=title,
        body=body,
        data=data,
        is_sent=False,
    )

    if not user.fcm_token:
        logger.debug(
            'send_push_notification: user %s has no FCM token, skipping send', user_id
        )
        return

    # Ensure all data values are strings (FCM requirement)
    str_data = {str(k): str(v) for k, v in data.items()}

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=str_data,
        token=user.fcm_token,
        android=messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                sound='default',
                click_action='FLUTTER_NOTIFICATION_CLICK',
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound='default', badge=1, content_available=True)
            )
        ),
    )

    try:
        messaging.send(message)
        now = timezone.now()
        log.is_sent = True
        log.sent_at = now
        log.save(update_fields=['is_sent', 'sent_at'])
        logger.info('Push sent to user=%s title=%s', user_id, title)

    except messaging.UnregisteredError:
        # Token is no longer valid — clear it so we don't keep trying
        logger.warning(
            'FCM token expired for user=%s, clearing token', user_id
        )
        User.objects.filter(id=user_id).update(fcm_token='')

    except messaging.QuotaExceededError:
        logger.error('FCM quota exceeded for user=%s', user_id)
        raise self.retry(countdown=60)

    except FirebaseError as exc:
        logger.error('Firebase error for user=%s: %s', user_id, exc)
        raise self.retry(exc=exc)

    except Exception as exc:
        logger.exception('Unexpected error sending push to user=%s', user_id)
        raise self.retry(exc=exc)


# ── Broadcast new message ──────────────────────────────────────────────────

@shared_task(
    bind=True,
    max_retries=2,
    default_retry_delay=5,
    name='notifications.broadcast_new_message',
)
def broadcast_new_message(self, message_id: str):
    """
    Called after a new message is saved.

    For each conversation member (except the sender):
      1. Update MessageStatus → is_delivered=True
      2. If the member is offline → send push notification
      3. Broadcast message.delivered via the chat channel group
      4. Broadcast new.message.notification to the member's personal channel
    """
    from apps.messages.models import Message, MessageStatus
    from apps.conversations.models import ConversationMember

    try:
        message = Message.objects.select_related(
            'sender', 'conversation'
        ).get(id=message_id)
    except Message.DoesNotExist:
        logger.warning('broadcast_new_message: message %s not found', message_id)
        return

    channel_layer = get_channel_layer()
    if channel_layer is None:
        logger.warning('broadcast_new_message: channel layer not configured')
        return

    sender = message.sender
    conv = message.conversation
    now = timezone.now()

    sender_name = (sender.name or sender.phone_number) if sender else 'مستخدم'
    content_preview = (
        message.content[:50]
        if message.type == 'text' and not message.is_deleted
        else f'[{message.get_type_display()}]'
    )

    # Count total unread in this conversation for the group
    total_members = ConversationMember.objects.filter(conversation=conv).count()

    members = (
        ConversationMember.objects
        .filter(conversation=conv)
        .exclude(user=sender)
        .select_related('user')
    )

    for membership in members:
        member = membership.user

        # ── 1. Update delivery status ──────────────────────────────────
        MessageStatus.objects.filter(
            message=message,
            user=member,
            is_delivered=False,
        ).update(is_delivered=True, delivered_at=now)

        # ── 2. Push notification for offline members ───────────────────
        if not member.is_online:
            unread_count = (
                MessageStatus.objects
                .filter(user=member, is_read=False,
                        message__conversation=conv)
                .count()
            )
            send_push_notification.delay(
                str(member.id),
                f'رسالة جديدة من {sender_name}',
                content_preview,
                {
                    'type': 'new_message',
                    'conversation_id': str(conv.id),
                    'message_id': str(message.id),
                    'sender_id': str(sender.id) if sender else '',
                },
            )

        # ── 3. Broadcast message.delivered to chat group ───────────────
        try:
            async_to_sync(channel_layer.group_send)(
                f'chat_{conv.id}',
                {
                    'type': 'message.delivered',
                    'message_id': str(message.id),
                    'user_id': str(member.id),
                    'delivered_at': now.isoformat(),
                },
            )
        except Exception as exc:
            logger.warning(
                'broadcast_new_message: group_send failed for chat_%s: %s',
                conv.id,
                exc,
            )

        # ── 4. Notify personal notification channel ────────────────────
        unread_count = (
            MessageStatus.objects
            .filter(user=member, is_read=False, message__conversation=conv)
            .count()
        )
        try:
            async_to_sync(channel_layer.group_send)(
                f'notifications_{member.id}',
                {
                    'type': 'new.message.notification',
                    'conversation_id': str(conv.id),
                    'sender_name': sender_name,
                    'message_preview': content_preview,
                    'unread_count': unread_count,
                },
            )
        except Exception as exc:
            logger.warning(
                'broadcast_new_message: notifications group_send failed for user=%s: %s',
                member.id,
                exc,
            )
