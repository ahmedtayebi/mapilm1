import logging

from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from .backends import FirebaseAuthBackend
from .models import BlockedUser, Contact, InviteLink, User
from .serializers import (
    FirebaseTokenSerializer,
    LogoutSerializer,
    PublicUserSerializer,
    UpdateProfileSerializer,
    UserSerializer,
)
from .utils import generate_jwt_tokens, get_user_avatar_url, verify_firebase_token

logger = logging.getLogger(__name__)


# ── Auth ─────────────────────────────────────────────────────────────────────

class VerifyFirebaseTokenView(APIView):
    """
    POST /api/auth/verify/
    Exchange a Firebase ID token for JWT access + refresh tokens.
    Creates the user account on first login.
    """

    permission_classes = [AllowAny]
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = FirebaseTokenSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        firebase_token = serializer.validated_data['firebase_token']

        try:
            decoded = verify_firebase_token(firebase_token)
        except ValueError as exc:
            return Response(
                {'error': True, 'detail': str(exc)},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        uid = decoded.get('uid')
        phone_number = decoded.get('phone_number', '')

        if not uid:
            return Response(
                {'error': True, 'detail': 'رمز المصادقة لا يحتوي على معرّف المستخدم'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # Get or create user
        user, created = User.objects.get_or_create(
            firebase_uid=uid,
            defaults={'phone_number': phone_number},
        )

        if not user.is_active:
            return Response(
                {'error': True, 'detail': 'هذا الحساب معطّل، تواصل مع الدعم'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Sync phone number if it changed
        if not created and phone_number and user.phone_number != phone_number:
            user.phone_number = phone_number
            user.save(update_fields=['phone_number'])

        # Mark online
        user.is_online = True
        user.save(update_fields=['is_online'])

        tokens = generate_jwt_tokens(user)

        return Response(
            {
                'access': tokens['access'],
                'refresh': tokens['refresh'],
                'user': {
                    'id': str(user.id),
                    'phone_number': user.phone_number,
                    'name': user.name,
                    'avatar_url': get_user_avatar_url(user),
                    'status': user.status,
                    'is_profile_complete': user.is_profile_complete,
                },
                'is_new_user': created,
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class RefreshTokenView(APIView):
    """
    POST /api/auth/refresh/
    Issue a new access token (and rotated refresh token) from a valid refresh token.
    """

    permission_classes = [AllowAny]
    parser_classes = [JSONParser]

    def post(self, request):
        refresh_token = request.data.get('refresh', '').strip()
        if not refresh_token:
            return Response(
                {'error': True, 'detail': 'رمز التحديث مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            token = RefreshToken(refresh_token)
            new_access = str(token.access_token)

            # ROTATE_REFRESH_TOKENS blacklists old and returns new
            token.blacklist()
            new_refresh = str(RefreshToken.for_user(
                User.objects.get(id=token['user_id'])
            ))
        except TokenError as exc:
            return Response(
                {'error': True, 'detail': 'رمز التحديث غير صالح أو منتهي الصلاحية'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        except User.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'المستخدم غير موجود'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        return Response(
            {'access': new_access, 'refresh': new_refresh},
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    """
    POST /api/auth/logout/
    Blacklist the refresh token, clear FCM token, mark user offline.
    Requires JWT authentication.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        refresh_token = serializer.validated_data['refresh']

        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response(
                {'error': True, 'detail': 'رمز التحديث غير صالح أو منتهي الصلاحية'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Mark offline and clear FCM token
        user = request.user
        user.is_online = False
        user.last_seen = timezone.now()
        user.fcm_token = ''
        user.save(update_fields=['is_online', 'last_seen', 'fcm_token'])

        return Response(
            {'message': 'تم تسجيل الخروج بنجاح'},
            status=status.HTTP_200_OK,
        )


# ── User profile ─────────────────────────────────────────────────────────────

class GetMyProfileView(APIView):
    """
    GET /api/users/me/
    Return the authenticated user's full profile.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)


class UpdateProfileView(APIView):
    """
    PUT /api/users/profile/update/
    Update name, avatar, and/or status.
    Sets is_profile_complete = True on first name submission.
    Supports multipart (avatar upload) and JSON.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def put(self, request):
        serializer = UpdateProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = serializer.save()

        return Response(
            {
                'message': 'تم تحديث الملف الشخصي بنجاح',
                'user': UserSerializer(user).data,
            },
            status=status.HTTP_200_OK,
        )


class SearchUserView(APIView):
    """
    GET /api/users/search/?phone=+213...
    Search for a user by exact phone number.
    Excludes the requesting user and blocked users.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        phone = request.query_params.get('phone', '').strip()

        if not phone:
            return Response(
                {'error': True, 'detail': 'يرجى تقديم رقم الهاتف في المعامل phone'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Cannot search for yourself
        if phone == request.user.phone_number:
            return Response(
                {'error': True, 'detail': 'لا يمكنك البحث عن نفسك'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # IDs the requesting user has blocked
        blocked_ids = BlockedUser.objects.filter(
            blocker=request.user
        ).values_list('blocked_id', flat=True)

        try:
            user = User.objects.get(phone_number=phone, is_active=True)
        except User.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'لم يتم العثور على مستخدم بهذا الرقم'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if user.id in blocked_ids:
            return Response(
                {'error': True, 'detail': 'لم يتم العثور على مستخدم بهذا الرقم'},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            PublicUserSerializer(user).data,
            status=status.HTTP_200_OK,
        )


class UpdateFCMTokenView(APIView):
    """
    POST /api/users/fcm-token/
    Store the device's FCM registration token for push notifications.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser]

    def post(self, request):
        token = request.data.get('fcm_token', '').strip()

        if not token:
            return Response(
                {'error': True, 'detail': 'fcm_token مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        request.user.fcm_token = token
        request.user.save(update_fields=['fcm_token'])

        return Response(
            {'message': 'تم تحديث رمز الإشعارات بنجاح'},
            status=status.HTTP_200_OK,
        )


# ── Contacts ──────────────────────────────────────────────────────────────

class ContactListView(APIView):
    """
    GET /api/v1/contacts/
    Return all contacts for the authenticated user.
    Each contact shows whether they are registered in Mapilm.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        contacts = (
            Contact.objects
            .filter(owner=request.user)
            .select_related('contact_user')
            .order_by('nickname', 'contact_user__name')
        )

        data = []
        for c in contacts:
            user = c.contact_user
            data.append({
                'id': str(c.id),
                'nickname': c.nickname,
                'user': PublicUserSerializer(user, context={'request': request}).data,
                'created_at': c.created_at.isoformat(),
            })

        return Response(data, status=status.HTTP_200_OK)


class AddContactView(APIView):
    """
    POST /api/v1/contacts/add/
    Body: { "phone_number": "+213...", "nickname": "..." }
    Find the user and add them to contacts.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser]

    def post(self, request):
        phone_number = request.data.get('phone_number', '').strip()
        nickname = request.data.get('nickname', '').strip()

        if not phone_number:
            return Response(
                {'error': True, 'detail': 'رقم الهاتف مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if phone_number == request.user.phone_number:
            return Response(
                {'error': True, 'detail': 'لا يمكنك إضافة نفسك إلى جهات الاتصال'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            target = User.objects.get(phone_number=phone_number, is_active=True)
        except User.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'لم يتم العثور على مستخدم بهذا الرقم'},
                status=status.HTTP_404_NOT_FOUND,
            )

        contact, created = Contact.objects.get_or_create(
            owner=request.user,
            contact_user=target,
            defaults={'nickname': nickname},
        )

        if not created and nickname:
            contact.nickname = nickname
            contact.save(update_fields=['nickname'])

        return Response(
            {
                'message': 'تمت إضافة جهة الاتصال بنجاح' if created else 'جهة الاتصال محدّثة',
                'contact': {
                    'id': str(contact.id),
                    'nickname': contact.nickname,
                    'user': PublicUserSerializer(target, context={'request': request}).data,
                    'created_at': contact.created_at.isoformat(),
                },
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class BlockUserView(APIView):
    """
    POST /api/v1/contacts/block/{user_id}/
    Block a user and remove them from contacts if they exist there.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, user_id):
        if str(user_id) == str(request.user.id):
            return Response(
                {'error': True, 'detail': 'لا يمكنك حظر نفسك'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            target = User.objects.get(id=user_id, is_active=True)
        except User.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'المستخدم غير موجود'},
                status=status.HTTP_404_NOT_FOUND,
            )

        _, created = BlockedUser.objects.get_or_create(
            blocker=request.user,
            blocked=target,
        )

        # Remove from contacts in both directions
        Contact.objects.filter(
            owner=request.user, contact_user=target
        ).delete()
        Contact.objects.filter(
            owner=target, contact_user=request.user
        ).delete()

        return Response(
            {'message': 'تم الحظر بنجاح'},
            status=status.HTTP_200_OK,
        )


class UnblockUserView(APIView):
    """
    DELETE /api/v1/contacts/unblock/{user_id}/
    Remove a user from the blocked list.
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request, user_id):
        deleted, _ = BlockedUser.objects.filter(
            blocker=request.user,
            blocked_id=user_id,
        ).delete()

        if deleted == 0:
            return Response(
                {'error': True, 'detail': 'هذا المستخدم غير محظور'},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            {'message': 'تم إلغاء الحظر بنجاح'},
            status=status.HTTP_200_OK,
        )


# ── Invite links ──────────────────────────────────────────────────────────

class GenerateInviteLinkView(APIView):
    """
    POST /api/v1/invite/generate/
    Create or return the existing invite link for the authenticated user.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        invite, _ = InviteLink.objects.get_or_create(owner=request.user)
        base_url = 'https://mapilm.app/invite'
        return Response(
            {
                'invite_url': f'{base_url}/{invite.token}',
                'token': str(invite.token),
                'uses_count': invite.uses_count,
            },
            status=status.HTTP_200_OK,
        )


class UseInviteLinkView(APIView):
    """
    GET /api/v1/invite/{token}/
    Resolve an invite link, increment the counter, and return the owner's public profile.
    Flutter uses the returned profile to start a conversation with the owner.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, token):
        try:
            invite = InviteLink.objects.select_related('owner').get(token=token)
        except InviteLink.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'رابط الدعوة غير صالح أو منتهي'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if invite.owner == request.user:
            return Response(
                {'error': True, 'detail': 'لا يمكنك استخدام رابط الدعوة الخاص بك'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Increment usage counter atomically
        InviteLink.objects.filter(id=invite.id).update(
            uses_count=invite.uses_count + 1
        )

        return Response(
            {
                'message': 'تم قبول الدعوة، يمكنك الآن بدء محادثة',
                'owner': PublicUserSerializer(invite.owner, context={'request': request}).data,
            },
            status=status.HTTP_200_OK,
        )
