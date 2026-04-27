from rest_framework import serializers

from apps.users.serializers import PublicUserSerializer
from .models import Media, Message, MessageStatus


class MediaSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model = Media
        fields = ['file_url', 'file_type', 'file_size', 'duration', 'thumbnail_url']

    def get_file_url(self, obj):
        return obj.file_url

    def get_thumbnail_url(self, obj):
        return obj.thumbnail_url


class ReplyPreviewSerializer(serializers.ModelSerializer):
    """Lightweight nested serializer used inside MessageSerializer.reply_to."""

    sender_name = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'type', 'content', 'sender_name', 'is_deleted']

    def get_sender_name(self, obj):
        if obj.sender:
            return obj.sender.name or obj.sender.phone_number
        return None


class MessagePreviewSerializer(serializers.ModelSerializer):
    """Compact serializer used in conversation list (last_message field)."""

    sender_name = serializers.SerializerMethodField()
    content_preview = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'type', 'content_preview', 'sender_name', 'created_at']

    def get_sender_name(self, obj):
        if obj.is_deleted:
            return None
        return obj.sender.name or obj.sender.phone_number if obj.sender else None

    def get_content_preview(self, obj):
        if obj.is_deleted:
            return 'تم حذف هذه الرسالة'
        if obj.type == Message.TYPE_TEXT:
            return obj.content[:50]
        return f'[{obj.get_type_display()}]'


class MessageSerializer(serializers.ModelSerializer):
    """Full serializer for a single message."""

    sender = PublicUserSerializer(read_only=True)
    media = MediaSerializer(read_only=True)
    reply_to = ReplyPreviewSerializer(read_only=True)
    status = serializers.SerializerMethodField()
    content = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            'id',
            'conversation',
            'sender',
            'type',
            'content',
            'is_deleted',
            'media',
            'reply_to',
            'status',
            'created_at',
        ]

    def get_content(self, obj):
        if obj.is_deleted:
            return 'تم حذف هذه الرسالة'
        return obj.content

    def get_status(self, obj):
        """
        Compute delivery/read status from MessageStatus rows.
        Only meaningful when the requesting user is the sender.
        """
        request = self.context.get('request')
        if not request or not obj.sender:
            return 'sent'

        if obj.sender_id != request.user.id:
            return 'received'

        statuses = list(obj.statuses.all())
        if not statuses:
            return 'sent'

        all_read = all(s.is_read for s in statuses)
        if all_read:
            return 'read'

        all_delivered = all(s.is_delivered for s in statuses)
        if all_delivered:
            return 'delivered'

        return 'sent'


class SendMessageSerializer(serializers.Serializer):
    """Input serializer for POST /api/v1/messages/send/"""

    conversation_id = serializers.UUIDField(
        error_messages={'required': 'معرّف المحادثة مطلوب'}
    )
    type = serializers.ChoiceField(
        choices=[Message.TYPE_TEXT, Message.TYPE_IMAGE, Message.TYPE_VOICE],
        error_messages={
            'required': 'نوع الرسالة مطلوب',
            'invalid_choice': 'النوع يجب أن يكون: text، image، أو voice',
        },
    )
    content = serializers.CharField(
        required=False,
        allow_blank=True,
        default='',
    )
    file = serializers.FileField(required=False, allow_null=True)
    reply_to_id = serializers.UUIDField(required=False, allow_null=True)

    def validate(self, data):
        msg_type = data.get('type')
        content = data.get('content', '').strip()
        file = data.get('file')

        if msg_type == Message.TYPE_TEXT and not content:
            raise serializers.ValidationError(
                {'content': 'المحتوى مطلوب للرسائل النصية'}
            )
        if msg_type in (Message.TYPE_IMAGE, Message.TYPE_VOICE) and not file:
            raise serializers.ValidationError(
                {'file': 'الملف مطلوب لرسائل الصور والصوت'}
            )
        return data
