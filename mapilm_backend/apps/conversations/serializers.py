import uuid

from rest_framework import serializers

from apps.users.models import BlockedUser, User
from apps.users.serializers import PublicUserSerializer
from apps.messages.serializers import MessagePreviewSerializer
from .models import Conversation, ConversationMember


class ConversationMemberSerializer(serializers.ModelSerializer):
    user = PublicUserSerializer(read_only=True)

    class Meta:
        model = ConversationMember
        fields = ['user', 'role', 'joined_at', 'is_muted']


class ConversationSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    members_count = serializers.SerializerMethodField()
    other_user = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id',
            'type',
            'name',
            'avatar_url',
            'last_message',
            'unread_count',
            'members_count',
            'other_user',
            'is_archived',
            'updated_at',
        ]

    def _requesting_user(self):
        return self.context['request'].user

    def get_avatar_url(self, obj):
        return obj.avatar_url

    def get_last_message(self, obj):
        msg = (
            obj.messages
            .select_related('sender')
            .order_by('-created_at')
            .first()
        )
        if msg is None:
            return None
        return MessagePreviewSerializer(msg, context=self.context).data

    def get_unread_count(self, obj):
        user = self._requesting_user()
        try:
            membership = obj.memberships.get(user=user)
        except ConversationMember.DoesNotExist:
            return 0

        qs = obj.messages.exclude(sender=user)
        if membership.last_read_at:
            qs = qs.filter(created_at__gt=membership.last_read_at)
        return qs.count()

    def get_members_count(self, obj):
        return obj.memberships.count()

    def get_other_user(self, obj):
        if obj.type != Conversation.TYPE_PRIVATE:
            return None
        user = self._requesting_user()
        other_membership = (
            obj.memberships
            .exclude(user=user)
            .select_related('user')
            .first()
        )
        if not other_membership:
            return None
        return PublicUserSerializer(other_membership.user, context=self.context).data


class CreatePrivateConversationSerializer(serializers.Serializer):
    user_id = serializers.UUIDField(
        error_messages={
            'required': 'معرّف المستخدم مطلوب',
            'invalid': 'معرّف المستخدم غير صالح',
        }
    )

    def validate_user_id(self, value):
        request = self.context['request']

        if value == request.user.id:
            raise serializers.ValidationError('لا يمكنك بدء محادثة مع نفسك')

        try:
            target = User.objects.get(id=value, is_active=True)
        except User.DoesNotExist:
            raise serializers.ValidationError('المستخدم غير موجود')

        if BlockedUser.objects.filter(
            blocker=request.user, blocked=target
        ).exists():
            raise serializers.ValidationError('لا يمكنك بدء محادثة مع مستخدم محظور')

        if BlockedUser.objects.filter(
            blocker=target, blocked=request.user
        ).exists():
            raise serializers.ValidationError('لا يمكنك بدء محادثة مع هذا المستخدم')

        self._target_user = target
        return value

    @property
    def target_user(self):
        return self._target_user


class CreateGroupSerializer(serializers.Serializer):
    name = serializers.CharField(
        max_length=120,
        error_messages={
            'required': 'اسم المجموعة مطلوب',
            'blank': 'اسم المجموعة لا يمكن أن يكون فارغاً',
            'max_length': 'اسم المجموعة يجب ألا يتجاوز 120 حرفاً',
        },
    )
    avatar = serializers.ImageField(required=False, allow_null=True)
    member_ids = serializers.ListField(
        child=serializers.UUIDField(),
        min_length=2,
        error_messages={
            'required': 'قائمة الأعضاء مطلوبة',
            'min_length': 'يجب أن تحتوي المجموعة على عضوين على الأقل',
        },
    )

    def validate_name(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError('اسم المجموعة يجب أن يكون 3 أحرف على الأقل')
        return value

    def validate_member_ids(self, value):
        request = self.context['request']

        # Remove duplicates while preserving order
        seen = set()
        unique_ids = []
        for uid in value:
            if uid not in seen and uid != request.user.id:
                seen.add(uid)
                unique_ids.append(uid)

        if len(unique_ids) < 2:
            raise serializers.ValidationError('يجب إضافة عضوين على الأقل (غير المنشئ)')

        existing_ids = set(
            User.objects.filter(id__in=unique_ids, is_active=True)
            .values_list('id', flat=True)
        )
        missing = [str(uid) for uid in unique_ids if uid not in existing_ids]
        if missing:
            raise serializers.ValidationError(
                f'المستخدمون التاليون غير موجودون: {", ".join(missing)}'
            )

        return unique_ids


class UpdateGroupSerializer(serializers.Serializer):
    name = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=False,
        error_messages={
            'blank': 'اسم المجموعة لا يمكن أن يكون فارغاً',
            'max_length': 'اسم المجموعة يجب ألا يتجاوز 120 حرفاً',
        },
    )
    avatar = serializers.ImageField(required=False, allow_null=True)

    def validate_name(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError('اسم المجموعة يجب أن يكون 3 أحرف على الأقل')
        return value

    def validate(self, data):
        if not data.get('name') and 'avatar' not in data:
            raise serializers.ValidationError('يجب تحديد الاسم أو الصورة على الأقل')
        return data
