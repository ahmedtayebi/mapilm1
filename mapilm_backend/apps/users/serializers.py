from rest_framework import serializers

from .models import User
from .utils import get_user_avatar_url


class UserSerializer(serializers.ModelSerializer):
    """Full read-only representation returned after auth and on profile requests."""

    avatar_url = serializers.SerializerMethodField()
    is_profile_complete = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'phone_number',
            'name',
            'avatar_url',
            'status',
            'is_online',
            'last_seen',
            'is_profile_complete',
            'created_at',
        ]
        read_only_fields = fields

    def get_avatar_url(self, obj):
        return get_user_avatar_url(obj)


class PublicUserSerializer(serializers.ModelSerializer):
    """Minimal representation used in search results and participant lists."""

    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'phone_number',
            'name',
            'avatar_url',
            'status',
            'is_online',
            'is_profile_complete',
        ]
        read_only_fields = fields

    def get_avatar_url(self, obj):
        return get_user_avatar_url(obj)


class UpdateProfileSerializer(serializers.ModelSerializer):
    """Write serializer for profile update endpoint."""

    name = serializers.CharField(
        max_length=50,
        required=False,
        allow_blank=False,
        error_messages={
            'blank': 'الاسم لا يمكن أن يكون فارغاً',
            'max_length': 'الاسم يجب ألا يتجاوز 50 حرفاً',
        },
    )
    status = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True,
        error_messages={
            'max_length': 'الحالة يجب ألا تتجاوز 100 حرف',
        },
    )
    avatar = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = User
        fields = ['name', 'avatar', 'status']

    def validate_name(self, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise serializers.ValidationError('الاسم يجب أن يكون على الأقل حرفين')
        return value

    def validate_status(self, value: str) -> str:
        return value.strip()

    def update(self, instance, validated_data):
        name = validated_data.get('name')

        # First time a name is given → mark profile complete
        if name and not instance.is_profile_complete:
            validated_data['is_profile_complete'] = True

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()
        return instance


class FirebaseTokenSerializer(serializers.Serializer):
    """Input for the Firebase verify endpoint."""

    firebase_token = serializers.CharField(
        required=True,
        allow_blank=False,
        error_messages={
            'required': 'رمز Firebase مطلوب',
            'blank': 'رمز Firebase لا يمكن أن يكون فارغاً',
        },
    )


class RefreshTokenInputSerializer(serializers.Serializer):
    """Input for the refresh endpoint."""

    refresh = serializers.CharField(
        required=True,
        allow_blank=False,
        error_messages={
            'required': 'رمز التحديث مطلوب',
            'blank': 'رمز التحديث لا يمكن أن يكون فارغاً',
        },
    )


class LogoutSerializer(serializers.Serializer):
    """Input for the logout endpoint."""

    refresh = serializers.CharField(
        required=True,
        allow_blank=False,
        error_messages={
            'required': 'رمز التحديث مطلوب لتسجيل الخروج',
            'blank': 'رمز التحديث لا يمكن أن يكون فارغاً',
        },
    )
