import json
import logging
from datetime import datetime

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import UntypedToken

from apps.conversations.models import Conversation, ConversationMember
from apps.messages.models import Media, Message, MessageStatus

User = get_user_model()
logger = logging.getLogger(__name__)


# ── DB helpers (all must run inside database_sync_to_async) ────────────────

@database_sync_to_async
def _get_user_by_id(user_id):
    try:
        return User.objects.get(id=user_id, is_active=True)
    except User.DoesNotExist:
        return None


@database_sync_to_async
def _get_membership(conversation_id, user):
    try:
        return ConversationMember.objects.select_related('conversation').get(
            conversation_id=conversation_id, user=user
        )
    except ConversationMember.DoesNotExist:
        return None


@database_sync_to_async
def _mark_user_online(user_id, online: bool):
    if online:
        User.objects.filter(id=user_id).update(is_online=True)
    else:
        User.objects.filter(id=user_id).update(
            is_online=False, last_seen=timezone.now()
        )


@database_sync_to_async
def _get_last_seen(user_id) -> str | None:
    try:
        user = User.objects.get(id=user_id)
        return user.last_seen.isoformat() if user.last_seen else None
    except User.DoesNotExist:
        return None


@database_sync_to_async
def _save_message(conversation_id, sender_id, msg_type, content, reply_to_id):
    """
    Persist a new Message and return the full message dict for broadcasting.
    """
    try:
        conv = Conversation.objects.get(id=conversation_id)
    except Conversation.DoesNotExist:
        raise ValueError('المحادثة غير موجودة')

    reply_to = None
    if reply_to_id:
        try:
            reply_to = Message.objects.get(id=reply_to_id, conversation=conv)
        except Message.DoesNotExist:
            pass  # ignore invalid reply_to silently

    msg = Message.objects.create(
        conversation=conv,
        sender_id=sender_id,
        type=msg_type,
        content=content or '',
        reply_to=reply_to,
    )

    # Create MessageStatus for every recipient (excludes sender)
    recipient_ids = list(
        ConversationMember.objects.filter(conversation=conv)
        .exclude(user_id=sender_id)
        .values_list('user_id', flat=True)
    )
    MessageStatus.objects.bulk_create(
        [
            MessageStatus(
                message=msg,
                user_id=uid,
                is_delivered=False,
                is_read=False,
            )
            for uid in recipient_ids
        ],
        ignore_conflicts=True,
    )

    # Touch conversation updated_at
    Conversation.objects.filter(id=conversation_id).update(updated_at=timezone.now())

    return _build_message_dict(msg)


def _build_message_dict(msg: Message) -> dict:
    """Build the wire-format dict for a Message (must be called inside a sync context)."""
    sender = msg.sender
    sender_dict = None
    if sender:
        sender_dict = {
            'id': str(sender.id),
            'name': sender.name or sender.phone_number,
            'avatar_url': sender.avatar_url,
        }

    media_dict = None
    try:
        m = msg.media
        media_dict = {
            'file_url': m.file_url,
            'file_type': m.file_type,
            'duration': m.duration,
        }
    except Media.DoesNotExist:
        pass

    reply_dict = None
    if msg.reply_to:
        r = msg.reply_to
        reply_dict = {
            'id': str(r.id),
            'content': r.content[:100] if not r.is_deleted else 'تم حذف هذه الرسالة',
            'sender_name': (
                r.sender.name or r.sender.phone_number if r.sender else None
            ),
        }

    return {
        'id': str(msg.id),
        'conversation_id': str(msg.conversation_id),
        'sender': sender_dict,
        'message_type': msg.type,
        'content': msg.content if not msg.is_deleted else 'تم حذف هذه الرسالة',
        'media': media_dict,
        'reply_to': reply_dict,
        'status': 'sent',
        'created_at': msg.created_at.isoformat(),
    }


@database_sync_to_async
def _mark_message_read(message_id, user_id) -> dict | None:
    """Mark one message as read for a user; return updated status info or None."""
    try:
        msg = Message.objects.get(id=message_id)
    except Message.DoesNotExist:
        return None

    now = timezone.now()
    status_obj, _ = MessageStatus.objects.get_or_create(
        message=msg,
        user_id=user_id,
        defaults={
            'is_delivered': True,
            'delivered_at': now,
            'is_read': True,
            'read_at': now,
        },
    )
    if not status_obj.is_read:
        status_obj.is_read = True
        status_obj.read_at = now
        if not status_obj.is_delivered:
            status_obj.is_delivered = True
            status_obj.delivered_at = now
        status_obj.save()

    # Update last_read_at for the membership
    ConversationMember.objects.filter(
        conversation=msg.conversation, user_id=user_id
    ).update(last_read_at=now)

    return {
        'message_id': str(message_id),
        'user_id': str(user_id),
        'read_at': now.isoformat(),
        'conversation_id': str(msg.conversation_id),
    }


@database_sync_to_async
def _update_last_seen(user_id):
    User.objects.filter(id=user_id).update(last_seen=timezone.now())


# ── Consumer ───────────────────────────────────────────────────────────────

class ChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for real-time chat.
    URL: ws://domain/ws/chat/{conversation_id}/?token=<jwt>
    """

    # ── Lifecycle ────────────────────────────────────────────────────────

    async def connect(self):
        self.user = None
        self.conversation_id = str(self.scope['url_route']['kwargs']['conversation_id'])
        self.room_group = f'chat_{self.conversation_id}'

        # 1. Verify JWT
        try:
            self.user = await self._authenticate()
        except ValueError as exc:
            logger.warning('WS auth failed: %s', exc)
            await self.close(code=4001)
            return

        # 2. Check membership
        membership = await _get_membership(self.conversation_id, self.user)
        if membership is None:
            logger.warning(
                'WS membership denied: user=%s conv=%s',
                self.user.id,
                self.conversation_id,
            )
            await self.close(code=4003)
            return

        # 3. Join group and accept
        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()

        # 4. Mark online and broadcast presence
        await _mark_user_online(self.user.id, True)
        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'user.online',
                'user_id': str(self.user.id),
            },
        )

    async def disconnect(self, close_code):
        if self.user is None:
            return

        await self.channel_layer.group_discard(self.room_group, self.channel_name)
        await _mark_user_online(self.user.id, False)
        last_seen = await _get_last_seen(self.user.id)

        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'user.offline',
                'user_id': str(self.user.id),
                'last_seen': last_seen,
            },
        )

    # ── Receive dispatcher ───────────────────────────────────────────────

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except (json.JSONDecodeError, TypeError):
            await self._send_error('تنسيق البيانات غير صالح، يرجى إرسال JSON صحيح')
            return

        event_type = data.get('type', '')

        dispatch = {
            'message.send': self._handle_message_send,
            'message.read': self._handle_message_read,
            'typing.start': self._handle_typing_start,
            'typing.stop': self._handle_typing_stop,
            'ping': self._handle_ping,
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
                'Unhandled error in %s handler (user=%s, conv=%s)',
                event_type,
                getattr(self.user, 'id', 'unknown'),
                self.conversation_id,
            )
            await self._send_error('حدث خطأ غير متوقع، يرجى المحاولة مجدداً')

    # ── Incoming event handlers ──────────────────────────────────────────

    async def _handle_message_send(self, data: dict):
        msg_type = data.get('message_type', 'text')
        content = data.get('content', '')
        reply_to_id = data.get('reply_to_id')

        if msg_type not in (Message.TYPE_TEXT, Message.TYPE_IMAGE, Message.TYPE_VOICE):
            raise ValueError('نوع الرسالة غير صالح، يُسمح بـ: text، image، voice')

        if msg_type == Message.TYPE_TEXT and not str(content).strip():
            raise ValueError('محتوى الرسالة النصية لا يمكن أن يكون فارغاً')

        message_dict = await _save_message(
            conversation_id=self.conversation_id,
            sender_id=self.user.id,
            msg_type=msg_type,
            content=content,
            reply_to_id=reply_to_id,
        )

        # Broadcast message.new to all group members (including sender)
        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'message.new',
                'message': message_dict,
            },
        )

        # Trigger async Celery task for push + delivery status
        from apps.notifications.tasks import broadcast_new_message  # late import
        broadcast_new_message.delay(message_dict['id'])

    async def _handle_message_read(self, data: dict):
        message_id = data.get('message_id')
        if not message_id:
            raise ValueError('message_id مطلوب')

        result = await _mark_message_read(message_id, self.user.id)
        if result is None:
            raise ValueError('الرسالة غير موجودة')

        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'message.read',
                'message_id': result['message_id'],
                'user_id': result['user_id'],
                'read_at': result['read_at'],
            },
        )

    async def _handle_typing_start(self, data: dict):
        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'typing.start',
                'user': {
                    'id': str(self.user.id),
                    'name': self.user.name or self.user.phone_number,
                },
                'conversation_id': self.conversation_id,
                '_sender_channel': self.channel_name,
            },
        )

    async def _handle_typing_stop(self, data: dict):
        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'typing.stop',
                'user_id': str(self.user.id),
                'conversation_id': self.conversation_id,
                '_sender_channel': self.channel_name,
            },
        )

    async def _handle_ping(self, data: dict):
        await _update_last_seen(self.user.id)
        await self.send(text_data=json.dumps({
            'type': 'pong',
            'timestamp': timezone.now().isoformat(),
        }))

    # ── Outgoing group event handlers ────────────────────────────────────
    # Channels maps 'type' dots to underscores when routing to methods.

    async def message_new(self, event: dict):
        await self.send(text_data=json.dumps({
            'type': 'message.new',
            'message': event['message'],
        }))

    async def message_delivered(self, event: dict):
        await self.send(text_data=json.dumps({
            'type': 'message.delivered',
            'message_id': event['message_id'],
            'user_id': event.get('user_id'),
            'delivered_at': event.get('delivered_at'),
        }))

    async def message_read(self, event: dict):
        await self.send(text_data=json.dumps({
            'type': 'message.read',
            'message_id': event['message_id'],
            'user_id': event['user_id'],
            'read_at': event['read_at'],
        }))

    async def message_deleted(self, event: dict):
        await self.send(text_data=json.dumps({
            'type': 'message.deleted',
            'message_id': event['message_id'],
        }))

    async def typing_start(self, event: dict):
        # Don't echo back to the sender
        if event.get('_sender_channel') == self.channel_name:
            return
        await self.send(text_data=json.dumps({
            'type': 'typing.start',
            'user': event['user'],
            'conversation_id': event['conversation_id'],
        }))

    async def typing_stop(self, event: dict):
        if event.get('_sender_channel') == self.channel_name:
            return
        await self.send(text_data=json.dumps({
            'type': 'typing.stop',
            'user_id': event['user_id'],
            'conversation_id': event['conversation_id'],
        }))

    async def user_online(self, event: dict):
        await self.send(text_data=json.dumps({
            'type': 'user.online',
            'user_id': event['user_id'],
        }))

    async def user_offline(self, event: dict):
        await self.send(text_data=json.dumps({
            'type': 'user.offline',
            'user_id': event['user_id'],
            'last_seen': event.get('last_seen'),
        }))

    # ── Auth helper ──────────────────────────────────────────────────────

    async def _authenticate(self) -> User:
        """
        Extract and verify the JWT token from the query string.
        Returns the authenticated User or raises ValueError.
        """
        qs = self.scope.get('query_string', b'').decode()
        token_str = None
        for part in qs.split('&'):
            if part.startswith('token='):
                token_str = part[len('token='):]
                break

        if not token_str:
            raise ValueError('رمز المصادقة مطلوب في معامل token')

        try:
            # UntypedToken validates the signature and expiry without a DB call
            validated = UntypedToken(token_str)
            user_id = validated.get('user_id')
        except (InvalidToken, TokenError) as exc:
            raise ValueError('رمز المصادقة غير صالح أو منتهي الصلاحية') from exc

        if not user_id:
            raise ValueError('رمز المصادقة لا يحتوي على معرّف المستخدم')

        user = await _get_user_by_id(user_id)
        if user is None:
            raise ValueError('المستخدم المرتبط بهذا الرمز غير موجود')

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
