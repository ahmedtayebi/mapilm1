import logging

import cloudinary.uploader
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.utils import timezone
from rest_framework import status
from rest_framework.pagination import CursorPagination
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.conversations.models import Conversation, ConversationMember
from .models import Media, Message, MessageStatus
from .serializers import MessageSerializer, SendMessageSerializer

logger = logging.getLogger(__name__)

# ── Allowed file types ─────────────────────────────────────────────────────
_IMAGE_TYPES = {'image/jpeg', 'image/jpg', 'image/png', 'image/webp'}
_VOICE_TYPES = {'audio/m4a', 'audio/mp4', 'audio/mpeg', 'audio/aac',
                'audio/x-m4a', 'audio/mp3'}
_IMAGE_MAX_BYTES = 10 * 1024 * 1024   # 10 MB
_VOICE_MAX_BYTES = 25 * 1024 * 1024   # 25 MB


# ── Pagination ─────────────────────────────────────────────────────────────

class MessageCursorPagination(CursorPagination):
    page_size = 50
    ordering = '-created_at'
    cursor_query_param = 'cursor'


# ── Helpers ────────────────────────────────────────────────────────────────

def _get_conversation_membership(conversation_id, user):
    """Return (conversation, membership) or (None, None) / (conv, None)."""
    try:
        conv = Conversation.objects.get(id=conversation_id)
    except Conversation.DoesNotExist:
        return None, None
    try:
        membership = conv.memberships.get(user=user)
    except ConversationMember.DoesNotExist:
        return conv, None
    return conv, membership


def _broadcast_ws(conversation_id, payload):
    """Fire-and-forget WebSocket broadcast; silently skips if Redis is down."""
    try:
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f'chat_{conversation_id}',
                payload,
            )
    except Exception as exc:
        logger.warning('WebSocket broadcast failed: %s', exc)


def _create_message_statuses(message, conversation, sender):
    """Create a MessageStatus row for each recipient (everyone except sender)."""
    recipients = (
        conversation.memberships
        .exclude(user=sender)
        .values_list('user_id', flat=True)
    )
    MessageStatus.objects.bulk_create(
        [
            MessageStatus(message=message, user_id=uid, is_delivered=False, is_read=False)
            for uid in recipients
        ],
        ignore_conflicts=True,
    )


# ── Views ──────────────────────────────────────────────────────────────────

class MessageListView(APIView):
    """
    GET /api/v1/messages/{conversation_id}/
    Cursor-paginated list of messages (newest first).
    Auto-marks fetched messages as delivered for the requesting user.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, conversation_id):
        conv, membership = _get_conversation_membership(conversation_id, request.user)

        if conv is None:
            return Response(
                {'error': True, 'detail': 'المحادثة غير موجودة'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if membership is None:
            return Response(
                {'error': True, 'detail': 'ليس لديك صلاحية الوصول لهذه المحادثة'},
                status=status.HTTP_403_FORBIDDEN,
            )

        queryset = (
            Message.objects
            .filter(conversation=conv)
            .select_related('sender', 'reply_to__sender')
            .prefetch_related('media', 'statuses')
            .order_by('-created_at')
        )

        paginator = MessageCursorPagination()
        page = paginator.paginate_queryset(queryset, request)

        # Auto-mark as delivered for all fetched messages
        if page:
            message_ids = [m.id for m in page if m.sender_id != request.user.id]
            if message_ids:
                now = timezone.now()
                MessageStatus.objects.filter(
                    message_id__in=message_ids,
                    user=request.user,
                    is_delivered=False,
                ).update(is_delivered=True, delivered_at=now)

        serializer = MessageSerializer(page, many=True, context={'request': request})
        return paginator.get_paginated_response(serializer.data)


class SendMessageView(APIView):
    """
    POST /api/v1/messages/send/
    Send a text, image, or voice message.
    Broadcasts via WebSocket for real-time delivery.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        serializer = SendMessageSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        data = serializer.validated_data
        conv, membership = _get_conversation_membership(
            data['conversation_id'], request.user
        )

        if conv is None:
            return Response(
                {'error': True, 'detail': 'المحادثة غير موجودة'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if membership is None:
            return Response(
                {'error': True, 'detail': 'لست عضواً في هذه المحادثة'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Validate reply_to exists and belongs to same conversation
        reply_to = None
        if data.get('reply_to_id'):
            try:
                reply_to = Message.objects.get(
                    id=data['reply_to_id'],
                    conversation=conv,
                )
            except Message.DoesNotExist:
                return Response(
                    {'error': True, 'detail': 'الرسالة المُجاب عليها غير موجودة'},
                    status=status.HTTP_404_NOT_FOUND,
                )

        # Create the message
        msg = Message.objects.create(
            conversation=conv,
            sender=request.user,
            type=data['type'],
            content=data.get('content', '').strip(),
            reply_to=reply_to,
        )

        # Handle media upload
        if data.get('file') and data['type'] in (Message.TYPE_IMAGE, Message.TYPE_VOICE):
            file_obj = data['file']
            file_type = data['type']

            try:
                resource_type = 'image' if file_type == Message.TYPE_IMAGE else 'video'
                upload_result = cloudinary.uploader.upload(
                    file_obj,
                    folder='mapilm/media',
                    resource_type=resource_type,
                )
                Media.objects.create(
                    message=msg,
                    file=upload_result.get('public_id', ''),
                    file_type=file_type,
                    file_size=file_obj.size,
                )
            except Exception as exc:
                logger.error('Cloudinary media upload failed: %s', exc)
                msg.delete()
                return Response(
                    {'error': True, 'detail': 'فشل رفع الملف، يرجى المحاولة مجدداً'},
                    status=status.HTTP_502_BAD_GATEWAY,
                )

        # Create delivery status rows for all recipients
        _create_message_statuses(msg, conv, request.user)

        # Touch conversation updated_at
        Conversation.objects.filter(id=conv.id).update(updated_at=timezone.now())

        # Broadcast via WebSocket (type matches ChatConsumer.message_new handler)
        msg_data = MessageSerializer(msg, context={'request': request}).data
        _broadcast_ws(
            str(conv.id),
            {
                'type': 'message.new',
                'message': msg_data,
            },
        )

        return Response(msg_data, status=status.HTTP_201_CREATED)


class UploadMediaView(APIView):
    """
    POST /api/v1/messages/upload-media/
    Pre-upload a file to Cloudinary without creating a message.
    Returns the URL and metadata for use in SendMessageView.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response(
                {'error': True, 'detail': 'الملف مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        content_type = file_obj.content_type or ''
        is_image = content_type in _IMAGE_TYPES
        is_voice = content_type in _VOICE_TYPES

        if not is_image and not is_voice:
            return Response(
                {'error': True, 'detail': 'نوع الملف غير مدعوم. يُسمح بـ jpg/png/webp/m4a/mp3/aac'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        max_size = _IMAGE_MAX_BYTES if is_image else _VOICE_MAX_BYTES
        if file_obj.size > max_size:
            limit_mb = max_size // (1024 * 1024)
            return Response(
                {'error': True, 'detail': f'حجم الملف يتجاوز الحد المسموح ({limit_mb} MB)'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            resource_type = 'image' if is_image else 'video'
            result = cloudinary.uploader.upload(
                file_obj,
                folder='mapilm/media',
                resource_type=resource_type,
            )
        except Exception as exc:
            logger.error('Cloudinary upload-media failed: %s', exc)
            return Response(
                {'error': True, 'detail': 'فشل رفع الملف إلى الخادم'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response(
            {
                'file_url': result.get('secure_url'),
                'public_id': result.get('public_id'),
                'file_size': file_obj.size,
                'file_type': 'image' if is_image else 'voice',
                'duration': result.get('duration'),
            },
            status=status.HTTP_201_CREATED,
        )


class MarkReadView(APIView):
    """
    POST /api/v1/messages/{id}/read/
    Mark a specific message as read for the authenticated user.
    Broadcasts a read receipt via WebSocket.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            msg = Message.objects.select_related('conversation').get(id=pk)
        except Message.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'الرسالة غير موجودة'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check membership
        if not msg.conversation.memberships.filter(user=request.user).exists():
            return Response(
                {'error': True, 'detail': 'ليس لديك صلاحية الوصول لهذه الرسالة'},
                status=status.HTTP_403_FORBIDDEN,
            )

        now = timezone.now()
        msg_status, _ = MessageStatus.objects.get_or_create(
            message=msg,
            user=request.user,
            defaults={
                'is_delivered': True,
                'delivered_at': now,
                'is_read': True,
                'read_at': now,
            },
        )

        if not msg_status.is_read:
            msg_status.is_read = True
            msg_status.read_at = now
            if not msg_status.is_delivered:
                msg_status.is_delivered = True
                msg_status.delivered_at = now
            msg_status.save()

        # Update last_read_at for this member
        ConversationMember.objects.filter(
            conversation=msg.conversation,
            user=request.user,
        ).update(last_read_at=now)

        # Broadcast read receipt (type matches ChatConsumer.message_read handler)
        _broadcast_ws(
            str(msg.conversation_id),
            {
                'type': 'message.read',
                'message_id': str(msg.id),
                'user_id': str(request.user.id),
                'read_at': now.isoformat(),
            },
        )

        return Response({'message': 'تم التحديث'}, status=status.HTTP_200_OK)


class DeleteMessageView(APIView):
    """
    DELETE /api/v1/messages/{id}/
    Soft-delete a message. Only the original sender may delete.
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        try:
            msg = Message.objects.select_related('conversation').get(id=pk)
        except Message.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'الرسالة غير موجودة'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if msg.sender_id != request.user.id:
            return Response(
                {'error': True, 'detail': 'لا يمكنك حذف رسائل الآخرين'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if msg.is_deleted:
            return Response(
                {'error': True, 'detail': 'هذه الرسالة محذوفة بالفعل'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        msg.soft_delete()

        # Broadcast deletion event
        _broadcast_ws(
            str(msg.conversation_id),
            {
                'type': 'message.deleted',
                'message_id': str(msg.id),
                'deleted_by': str(request.user.id),
            },
        )

        return Response({'message': 'تم حذف الرسالة'}, status=status.HTTP_200_OK)
