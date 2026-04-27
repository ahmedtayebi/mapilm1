import logging

import cloudinary
from firebase_admin import auth as firebase_auth
from firebase_admin.exceptions import FirebaseError
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

logger = logging.getLogger(__name__)


# ── JWT ─────────────────────────────────────────────────────────────────────

def generate_jwt_tokens(user) -> dict:
    """
    Generate a JWT access/refresh token pair for the given user.
    Returns {'access': '...', 'refresh': '...'}.
    """
    refresh = RefreshToken.for_user(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


# ── Firebase ─────────────────────────────────────────────────────────────────

def verify_firebase_token(token: str) -> dict:
    """
    Verify a Firebase ID token and return the decoded payload.
    Raises ValueError with an Arabic message on any failure.
    """
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded
    except firebase_auth.ExpiredIdTokenError:
        raise ValueError('انتهت صلاحية رمز المصادقة، يرجى إعادة تسجيل الدخول')
    except firebase_auth.RevokedIdTokenError:
        raise ValueError('تم إلغاء رمز المصادقة، يرجى إعادة تسجيل الدخول')
    except firebase_auth.InvalidIdTokenError:
        raise ValueError('رمز المصادقة غير صالح')
    except FirebaseError as exc:
        logger.error('Firebase verification error: %s', exc)
        raise ValueError('فشل التحقق من رمز المصادقة')
    except Exception as exc:
        logger.exception('Unexpected error during Firebase token verification')
        raise ValueError('حدث خطأ غير متوقع أثناء التحقق من الهوية')


# ── Cloudinary ───────────────────────────────────────────────────────────────

def get_user_avatar_url(user) -> str | None:
    """
    Return the full HTTPS Cloudinary URL for the user's avatar,
    or None if no avatar is set.
    """
    if not user.avatar:
        return None
    try:
        return user.avatar.url
    except Exception:
        return None


# ── DRF exception handler ────────────────────────────────────────────────────

def custom_exception_handler(exc, context):
    """
    Wrap DRF error responses in a consistent envelope:
    { "error": true, "detail": ..., "status_code": ... }
    """
    response = exception_handler(exc, context)
    if response is not None:
        response.data = {
            'error': True,
            'detail': response.data,
            'status_code': response.status_code,
        }
    return response
