import uuid
from cloudinary.models import CloudinaryField
from django.db import models
from apps.users.models import User


class Conversation(models.Model):
    TYPE_PRIVATE = 'private'
    TYPE_GROUP = 'group'
    TYPE_CHOICES = [
        (TYPE_PRIVATE, 'خاصة'),
        (TYPE_GROUP, 'مجموعة'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    type = models.CharField(
        max_length=10,
        choices=TYPE_CHOICES,
        default=TYPE_PRIVATE,
        verbose_name='النوع',
    )
    name = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='الاسم',
        help_text='للمجموعات فقط',
    )
    avatar = CloudinaryField(
        'avatar',
        folder='mapilm/groups',
        blank=True,
        null=True,
        resource_type='image',
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_conversations',
        verbose_name='أنشأها',
    )
    is_archived = models.BooleanField(default=False, verbose_name='مؤرشفة')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'conversations'
        verbose_name = 'محادثة'
        verbose_name_plural = 'المحادثات'
        ordering = ['-updated_at']

    def __str__(self):
        if self.type == self.TYPE_GROUP:
            return self.name or f'مجموعة {self.id}'
        members = self.memberships.select_related('user').values_list(
            'user__name', flat=True
        )[:2]
        return ' & '.join(members) or str(self.id)

    @property
    def avatar_url(self):
        return self.avatar.url if self.avatar else None

    @property
    def is_group(self):
        return self.type == self.TYPE_GROUP


class ConversationMember(models.Model):
    ROLE_MEMBER = 'member'
    ROLE_ADMIN = 'admin'
    ROLE_CHOICES = [
        (ROLE_MEMBER, 'عضو'),
        (ROLE_ADMIN, 'مشرف'),
    ]

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='memberships',
        verbose_name='المحادثة',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='conversation_memberships',
        verbose_name='المستخدم',
    )
    role = models.CharField(
        max_length=10,
        choices=ROLE_CHOICES,
        default=ROLE_MEMBER,
        verbose_name='الدور',
    )
    joined_at = models.DateTimeField(auto_now_add=True)
    last_read_at = models.DateTimeField(null=True, blank=True, verbose_name='آخر قراءة')
    is_muted = models.BooleanField(default=False, verbose_name='كتم الإشعارات')

    class Meta:
        db_table = 'conversation_members'
        unique_together = ('conversation', 'user')
        verbose_name = 'عضو في المحادثة'
        verbose_name_plural = 'أعضاء المحادثة'
        ordering = ['joined_at']

    def __str__(self):
        return f'{self.user} في {self.conversation} ({self.get_role_display()})'
