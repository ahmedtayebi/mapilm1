import json
import logging

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import UntypedToken

from .models import NotificationLog

User = get_user_model()
logger = logging.getLogger(__name__)


@database_sync_to_async
def _get_user_by_id(user_id):
    try:
        return User.objects.get(id=user_id, is_active=True)
    except User.DoesNotExist:
        return None


@database_sync_to_async
def _mark_notification_sent(notification_id, user_id):
    """
    No-op for now — notifications are tracked in NotificationLog.is_sent.
    This endpoint can be used by Flutter to acknowledge receipt.
    """
    return NotificationLog.objects.filter(
        id=notification_id, recipient_id=user_id
    ).update(is_sent=True, sent_at=timezone.now())


class NotificationConsumer(AsyncWebsocketConsumer):
    """
    Personal WebSocket channel for push-style notifications.
    URL: ws://domain/ws/notifications/?token=<jwt>

    Sends outgoing events:
      - new.message.notification
    Receives incoming events:
      - mark.read
    """

    # ── Lifecycle ────────────────────────────────────────────────────────

    async def connect(self):
        self.user = None
        self.personal_group = None

        try:
            self.user = await self._authenticate()
        except ValueError as exc:
            logger.warning('Notification WS auth failed: %s', exc)
            await self.close(code=4001)
            return

        self.personal_group = f'notifications_{self.user.id}'
        await self.channel_layer.group_add(self.personal_group, self.channel_name)
        await self.accept()

        logger.debug(
            'NotificationConsumer connected: user=%s group=%s',
            self.user.id,
            self.personal_group,
        )

    async def disconnect(self, close_code):
        if self.personal_group:
            await self.channel_layer.group_discard(
                self.personal_group, self.channel_name
            )

    # ── Receive dispatcher ───────────────────────────────────────────────

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except (json.JSONDecodeError, TypeError):
            await self._send_error('تنسيق البيانات غير صالح')
            return

        event_type = data.get('type', '')

        dispatch = {
            'mark.read': self._handle_mark_read,
        }

        handler = dispatch.get(event_type)
        if handler is None:
            await self._send_error(f'نوع الحدث غير معروف: {event_type}')
            return

        try:
            await handler(data)
        except ValueError as exc:
            await self._send_error(str(exc))
        except Exception:
            logger.exception(
                'Unhandled error in notification handler (user=%s)',
                getattr(self.user, 'id', 'unknown'),
            )
            await self._send_error('حدث خطأ غير متوقع')

    # ── Incoming event handlers ──────────────────────────────────────────

    async def _handle_mark_read(self, data: dict):
        notification_id = data.get('notification_id')
        if not notification_id:
            raise ValueError('notification_id مطلوب')

        updated = await _mark_notification_sent(notification_id, self.user.id)
        if updated == 0:
            raise ValueError('الإشعار غير موجود أو لا تملك صلاحية تعديله')

        await self.send(text_data=json.dumps({
            'type': 'mark.read.success',
            'notification_id': str(notification_id),
        }))

    # ── Outgoing group event handlers ────────────────────────────────────

    async def new_message_notification(self, event: dict):
        """Triggered by Celery task via channel_layer.group_send."""
        await self.send(text_data=json.dumps({
            'type': 'new.message.notification',
            'conversation_id': event.get('conversation_id'),
            'sender_name': event.get('sender_name'),
            'message_preview': event.get('message_preview'),
            'unread_count': event.get('unread_count', 0),
        }))

    # ── Auth helper ──────────────────────────────────────────────────────

    async def _authenticate(self) -> User:
        qs = self.scope.get('query_string', b'').decode()
        token_str = None
        for part in qs.split('&'):
            if part.startswith('token='):
                token_str = part[len('token='):]
                break

        if not token_str:
            raise ValueError('رمز المصادقة مطلوب في معامل token')

        try:
            validated = UntypedToken(token_str)
            user_id = validated.get('user_id')
        except (InvalidToken, TokenError) as exc:
            raise ValueError('رمز المصادقة غير صالح أو منتهي الصلاحية') from exc

        if not user_id:
            raise ValueError('رمز المصادقة لا يحتوي على معرّف المستخدم')

        user = await _get_user_by_id(user_id)
        if user is None:
            raise ValueError('المستخدم غير موجود')

        return user

    # ── Error helper ─────────────────────────────────────────────────────

    async def _send_error(self, message: str):
        try:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': message,
            }))
        except Exception:
            pass
