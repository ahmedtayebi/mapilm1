from firebase_admin import auth as firebase_auth
from firebase_admin.exceptions import FirebaseError

from .models import User


class FirebaseAuthBackend:
    """
    Django authentication backend.
    Verifies a Firebase ID token and returns the corresponding User,
    creating one on the fly if it does not yet exist.
    """

    def authenticate(self, request, firebase_token=None):
        if firebase_token is None:
            return None

        try:
            decoded = firebase_auth.verify_id_token(firebase_token)
        except firebase_auth.ExpiredIdTokenError:
            raise ValueError('انتهت صلاحية رمز المصادقة، يرجى إعادة تسجيل الدخول')
        except firebase_auth.RevokedIdTokenError:
            raise ValueError('تم إلغاء رمز المصادقة، يرجى إعادة تسجيل الدخول')
        except firebase_auth.InvalidIdTokenError:
            raise ValueError('رمز المصادقة غير صالح')
        except FirebaseError:
            raise ValueError('فشل التحقق من رمز المصادقة')
        except Exception:
            raise ValueError('حدث خطأ أثناء التحقق من الهوية')

        uid = decoded.get('uid')
        phone_number = decoded.get('phone_number', '')

        if not uid:
            raise ValueError('رمز المصادقة لا يحتوي على معرّف المستخدم')

        user, created = User.objects.get_or_create(
            firebase_uid=uid,
            defaults={'phone_number': phone_number},
        )

        if not user.is_active:
            raise ValueError('هذا الحساب معطّل، تواصل مع الدعم')

        # Sync phone if it changed in Firebase
        if not created and phone_number and user.phone_number != phone_number:
            user.phone_number = phone_number
            user.save(update_fields=['phone_number'])

        return user

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
