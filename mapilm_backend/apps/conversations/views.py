import logging

import cloudinary.uploader
from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import User
from .models import Conversation, ConversationMember
from .serializers import (
    ConversationMemberSerializer,
    ConversationSerializer,
    CreateGroupSerializer,
    CreatePrivateConversationSerializer,
    UpdateGroupSerializer,
)

logger = logging.getLogger(__name__)



def _get_membership(conversation_id, user):
    """
    Return (conversation, membership) or raise a Response-ready tuple.
    Usage: call and handle the exception if it's a Response.
    """
    try:
        conv = Conversation.objects.prefetch_related(
            'memberships__user'
        ).get(id=conversation_id)
    except Conversation.DoesNotExist:
        return None, None

    try:
        membership = conv.memberships.get(user=user)
    except ConversationMember.DoesNotExist:
        return conv, None

    return conv, membership


def _serialized_conversation(conv, request):
    return ConversationSerializer(conv, context={'request': request}).data



class ConversationListView(APIView):
    """
    GET /api/v1/conversations/
    Return all non-archived conversations for the authenticated user,
    ordered by updated_at descending.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        conversations = (
            Conversation.objects
            .filter(memberships__user=request.user, is_archived=False)
            .prefetch_related('memberships__user', 'messages__sender')
            .order_by('-updated_at')
            .distinct()
        )
        serializer = ConversationSerializer(
            conversations, many=True, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


# ── Create conversations ───────────────────────────────────────────────────

class CreatePrivateConversationView(APIView):
    """
    POST /api/v1/conversations/private/
    Get or create a private conversation with another user.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser]

    def post(self, request):
        serializer = CreatePrivateConversationSerializer(
            data=request.data, context={'request': request}
        )
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        target = serializer.target_user

        # Check if conversation already exists between both users
        existing = (
            Conversation.objects
            .filter(
                type=Conversation.TYPE_PRIVATE,
                memberships__user=request.user,
            )
            .filter(memberships__user=target)
            .first()
        )

        if existing:
            return Response(
                _serialized_conversation(existing, request),
                status=status.HTTP_200_OK,
            )

        with transaction.atomic():
            conv = Conversation.objects.create(
                type=Conversation.TYPE_PRIVATE,
                created_by=request.user,
            )
            ConversationMember.objects.bulk_create([
                ConversationMember(
                    conversation=conv,
                    user=request.user,
                    role=ConversationMember.ROLE_ADMIN,
                ),
                ConversationMember(
                    conversation=conv,
                    user=target,
                    role=ConversationMember.ROLE_MEMBER,
                ),
            ])

        return Response(
            _serialized_conversation(conv, request),
            status=status.HTTP_201_CREATED,
        )


class CreateGroupView(APIView):
    """
    POST /api/v1/conversations/group/
    Create a group conversation.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        serializer = CreateGroupSerializer(
            data=request.data, context={'request': request}
        )
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        data = serializer.validated_data
        avatar_public_id = None

        # Upload avatar to Cloudinary if provided
        if data.get('avatar'):
            try:
                upload_result = cloudinary.uploader.upload(
                    data['avatar'],
                    folder='mapilm/groups',
                    resource_type='image',
                )
                avatar_public_id = upload_result.get('public_id')
            except Exception as exc:
                logger.error('Cloudinary group avatar upload failed: %s', exc)
                return Response(
                    {'error': True, 'detail': 'فشل رفع صورة المجموعة'},
                    status=status.HTTP_502_BAD_GATEWAY,
                )

        with transaction.atomic():
            conv = Conversation.objects.create(
                type=Conversation.TYPE_GROUP,
                name=data['name'],
                created_by=request.user,
                avatar=avatar_public_id,
            )

            members = [
                ConversationMember(
                    conversation=conv,
                    user=request.user,
                    role=ConversationMember.ROLE_ADMIN,
                )
            ]
            member_users = User.objects.filter(id__in=data['member_ids'], is_active=True)
            for user in member_users:
                members.append(
                    ConversationMember(
                        conversation=conv,
                        user=user,
                        role=ConversationMember.ROLE_MEMBER,
                    )
                )
            ConversationMember.objects.bulk_create(members)

        return Response(
            _serialized_conversation(conv, request),
            status=status.HTTP_201_CREATED,
        )


# ── Conversation detail / archive ──────────────────────────────────────────

class ConversationDetailView(APIView):
    """
    GET /api/v1/conversations/{id}/
    Return full conversation details. Only members may access.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        conv, membership = _get_membership(pk, request.user)

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

        return Response(
            _serialized_conversation(conv, request),
            status=status.HTTP_200_OK,
        )


class ArchiveConversationView(APIView):
    """
    POST /api/v1/conversations/{id}/archive/
    Toggle the archived status of a conversation.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        conv, membership = _get_membership(pk, request.user)

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

        conv.is_archived = not conv.is_archived
        conv.save(update_fields=['is_archived'])

        state = 'تم أرشفة المحادثة' if conv.is_archived else 'تم إلغاء أرشفة المحادثة'
        return Response(
            {'message': state, 'is_archived': conv.is_archived},
            status=status.HTTP_200_OK,
        )


# ── Group members ──────────────────────────────────────────────────────────

class GroupMembersView(APIView):
    """
    GET /api/v1/conversations/{id}/members/
    List all members. Only members may view.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        conv, membership = _get_membership(pk, request.user)

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

        members = conv.memberships.select_related('user').order_by('joined_at')
        serializer = ConversationMemberSerializer(
            members, many=True, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class AddMemberView(APIView):
    """
    POST /api/v1/conversations/{id}/add-member/
    Admin-only: add a new member to a group.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser]

    def post(self, request, pk):
        conv, membership = _get_membership(pk, request.user)

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
        if not conv.is_group:
            return Response(
                {'error': True, 'detail': 'لا يمكن إضافة أعضاء في المحادثات الخاصة'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if membership.role != ConversationMember.ROLE_ADMIN:
            return Response(
                {'error': True, 'detail': 'فقط المشرفون يمكنهم إضافة أعضاء'},
                status=status.HTTP_403_FORBIDDEN,
            )

        user_id = request.data.get('user_id')
        if not user_id:
            return Response(
                {'error': True, 'detail': 'معرّف المستخدم مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            new_user = User.objects.get(id=user_id, is_active=True)
        except (User.DoesNotExist, ValueError):
            return Response(
                {'error': True, 'detail': 'المستخدم غير موجود'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if conv.memberships.filter(user=new_user).exists():
            return Response(
                {'error': True, 'detail': 'المستخدم عضو بالفعل في هذه المجموعة'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ConversationMember.objects.create(
            conversation=conv,
            user=new_user,
            role=ConversationMember.ROLE_MEMBER,
        )

        members = conv.memberships.select_related('user').order_by('joined_at')
        serializer = ConversationMemberSerializer(
            members, many=True, context={'request': request}
        )
        return Response(
            {'message': 'تمت إضافة العضو بنجاح', 'members': serializer.data},
            status=status.HTTP_201_CREATED,
        )


class RemoveMemberView(APIView):
    """
    DELETE /api/v1/conversations/{id}/remove-member/{user_id}/
    - Admin can remove any member.
    - Member can remove themselves (leave).
    - If the last admin leaves → promote the oldest remaining member.
    - If no members remain → delete the conversation.
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request, pk, user_id):
        conv, membership = _get_membership(pk, request.user)

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
        if not conv.is_group:
            return Response(
                {'error': True, 'detail': 'لا يمكن إزالة أعضاء من المحادثات الخاصة'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_self_removal = str(user_id) == str(request.user.id)

        if not is_self_removal and membership.role != ConversationMember.ROLE_ADMIN:
            return Response(
                {'error': True, 'detail': 'فقط المشرفون يمكنهم إزالة الأعضاء'},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            target_membership = conv.memberships.get(user_id=user_id)
        except ConversationMember.DoesNotExist:
            return Response(
                {'error': True, 'detail': 'المستخدم ليس عضواً في هذه المجموعة'},
                status=status.HTTP_404_NOT_FOUND,
            )

        with transaction.atomic():
            target_membership.delete()

            remaining = conv.memberships.order_by('joined_at')
            if not remaining.exists():
                conv.delete()
                return Response(
                    {'message': 'تمت مغادرة المجموعة وتم حذفها لأنه لم يتبق أعضاء'},
                    status=status.HTTP_200_OK,
                )

            # Ensure at least one admin remains
            if not remaining.filter(role=ConversationMember.ROLE_ADMIN).exists():
                oldest = remaining.first()
                oldest.role = ConversationMember.ROLE_ADMIN
                oldest.save(update_fields=['role'])

        msg = 'تمت مغادرة المجموعة بنجاح' if is_self_removal else 'تمت إزالة العضو بنجاح'
        return Response({'message': msg}, status=status.HTTP_200_OK)


class UpdateGroupView(APIView):
    """
    PUT /api/v1/conversations/{id}/update/
    Admin-only: update group name and/or avatar.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def put(self, request, pk):
        conv, membership = _get_membership(pk, request.user)

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
        if not conv.is_group:
            return Response(
                {'error': True, 'detail': 'هذه العملية خاصة بالمجموعات فقط'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if membership.role != ConversationMember.ROLE_ADMIN:
            return Response(
                {'error': True, 'detail': 'فقط المشرفون يمكنهم تعديل المجموعة'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = UpdateGroupSerializer(
            data=request.data, context={'request': request}
        )
        if not serializer.is_valid():
            return Response(
                {'error': True, 'detail': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        data = serializer.validated_data
        update_fields = []

        if data.get('name'):
            conv.name = data['name']
            update_fields.append('name')

        if data.get('avatar'):
            try:
                result = cloudinary.uploader.upload(
                    data['avatar'],
                    folder='mapilm/groups',
                    resource_type='image',
                )
                conv.avatar = result.get('public_id')
                update_fields.append('avatar')
            except Exception as exc:
                logger.error('Cloudinary group avatar update failed: %s', exc)
                return Response(
                    {'error': True, 'detail': 'فشل رفع صورة المجموعة'},
                    status=status.HTTP_502_BAD_GATEWAY,
                )

        if update_fields:
            update_fields.append('updated_at')
            conv.save(update_fields=update_fields)

        return Response(
            {
                'message': 'تم تحديث المجموعة بنجاح',
                'conversation': _serialized_conversation(conv, request),
            },
            status=status.HTTP_200_OK,
        )
