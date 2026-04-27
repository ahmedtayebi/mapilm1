from firebase_admin import auth as firebase_auth
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .models import User


class FirebaseAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if not auth_header.startswith('Bearer '):
            return None

        token = auth_header.split(' ')[1]
        try:
            decoded = firebase_auth.verify_id_token(token)
        except Exception:
            raise AuthenticationFailed('رمز المصادقة غير صالح أو منتهي الصلاحية')

        uid = decoded.get('uid')
        phone = decoded.get('phone_number', '')

        user, _ = User.objects.get_or_create(
            firebase_uid=uid,
            defaults={'phone_number': phone},
        )

        if not user.is_active:
            raise AuthenticationFailed('الحساب معطّل')

        return (user, token)
