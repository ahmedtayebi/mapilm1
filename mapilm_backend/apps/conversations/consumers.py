import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from firebase_admin import auth as firebase_auth

from apps.users.models import User
from apps.conversations.models import Conversation, ConversationMember
from apps.messages.models import Message


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group = f'chat_{self.conversation_id}'

        token = self.scope['query_string'].decode().split('token=')[-1]
        try:
            decoded = firebase_auth.verify_id_token(token)
            self.user = await self._get_user(decoded['uid'])
        except Exception:
            await self.close(code=4001)
            return

        if not await self._is_member():
            await self.close(code=4003)
            return

        await self._set_online(True)
        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()

    async def disconnect(self, code):
        await self._set_online(False)
        await self.channel_layer.group_discard(self.room_group, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        msg_type = data.get('type')

        if msg_type == 'chat_message':
            await self._handle_chat_message(data)
        elif msg_type == 'typing_start':
            await self._broadcast_typing(True)
        elif msg_type == 'typing_stop':
            await self._broadcast_typing(False)
        elif msg_type == 'mark_read':
            await self._handle_mark_read(data)
        elif msg_type == 'ping':
            await self.send(text_data=json.dumps({'type': 'pong'}))

    async def _handle_chat_message(self, data):
        content = data.get('content', '')
        message_type = data.get('message_type', 'text')
        reply_to_id = data.get('reply_to')
        media_url = data.get('media_url')

        msg = await self._save_message(
            content=content,
            message_type=message_type,
            reply_to_id=reply_to_id,
            media_url=media_url,
        )

        await self._increment_unread_for_others()

        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'chat.message',
                'id': str(msg.id),
                'conversation_id': self.conversation_id,
                'sender_id': str(self.user.id),
                'sender_name': self.user.name or self.user.phone,
                'sender_avatar': self.user.avatar_url,
                'content': content,
                'message_type': message_type,
                'media_url': media_url,
                'sent_at': msg.sent_at.isoformat(),
                'status': 'sent',
            },
        )

    async def _broadcast_typing(self, is_typing):
        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'typing.event',
                'user_id': str(self.user.id),
                'user_name': self.user.name or self.user.phone,
                'is_typing': is_typing,
            },
        )

    async def _handle_mark_read(self, data):
        await self._mark_read()
        await self.channel_layer.group_send(
            self.room_group,
            {
                'type': 'read.receipt',
                'user_id': str(self.user.id),
                'conversation_id': self.conversation_id,
            },
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'chat_message',
            **{k: v for k, v in event.items() if k != 'type'},
        }))

    async def typing_event(self, event):
        if str(self.user.id) != event['user_id']:
            await self.send(text_data=json.dumps({
                'type': 'typing',
                'user_id': event['user_id'],
                'user_name': event['user_name'],
                'is_typing': event['is_typing'],
            }))

    async def read_receipt(self, event):
        await self.send(text_data=json.dumps({
            'type': 'read_receipt',
            'user_id': event['user_id'],
            'conversation_id': event['conversation_id'],
        }))

    @database_sync_to_async
    def _get_user(self, uid):
        return User.objects.get(firebase_uid=uid)

    @database_sync_to_async
    def _is_member(self):
        return ConversationMember.objects.filter(
            conversation_id=self.conversation_id,
            user=self.user,
        ).exists()

    @database_sync_to_async
    def _set_online(self, online):
        User.objects.filter(id=self.user.id).update(
            is_online=online,
            last_seen=None if online else timezone.now(),
        )

    @database_sync_to_async
    def _save_message(self, content, message_type, reply_to_id, media_url):
        return Message.objects.create(
            conversation_id=self.conversation_id,
            sender=self.user,
            content=content,
            message_type=message_type,
            reply_to_id=reply_to_id,
            media_url=media_url or '',
        )

    @database_sync_to_async
    def _increment_unread_for_others(self):
        ConversationMember.objects.filter(
            conversation_id=self.conversation_id
        ).exclude(user=self.user).update(
            unread_count=models.F('unread_count') + 1
        )

    @database_sync_to_async
    def _mark_read(self):
        ConversationMember.objects.filter(
            conversation_id=self.conversation_id,
            user=self.user,
        ).update(unread_count=0, last_read_at=timezone.now())


from django.db import models  # noqa: E402 — needed for F() expression
