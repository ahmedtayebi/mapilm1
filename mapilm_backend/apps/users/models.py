import uuid
from cloudinary.models import CloudinaryField
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    def create_user(self, phone_number, firebase_uid, **extra_fields):
        if not phone_number:
            raise ValueError('رقم الهاتف مطلوب')
        user = self.model(
            phone_number=phone_number,
            firebase_uid=firebase_uid,
            **extra_fields,
        )
        user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone_number, firebase_uid, **extra_fields):
        extra_fields.setdefault('is_admin', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(phone_number, firebase_uid, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    firebase_uid = models.CharField(max_length=128, unique=True, db_index=True)
    phone_number = models.CharField(
        max_length=20,
        unique=True,
        db_index=True,
        help_text='رقم الهاتف بصيغة E.164 مثل +966501234567',
    )
    name = models.CharField(max_length=120, blank=True)
    avatar = CloudinaryField('avatar', folder='mapilm/avatars', blank=True, null=True, resource_type='image')
    status = models.CharField(max_length=300, blank=True, verbose_name='الحالة')
    last_seen = models.DateTimeField(null=True, blank=True)
    is_online = models.BooleanField(default=False)
    fcm_token = models.TextField(blank=True, verbose_name='FCM Token')
    is_profile_complete = models.BooleanField(
        default=False,
        verbose_name='الملف مكتمل',
        help_text='يصبح True عند تعيين الاسم لأول مرة',
    )
    is_active = models.BooleanField(default=True)
    is_admin = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = 'phone_number'
    REQUIRED_FIELDS = ['firebase_uid']

    class Meta:
        db_table = 'users'
        verbose_name = 'مستخدم'
        verbose_name_plural = 'المستخدمون'
        ordering = ['-created_at']

    # Django admin requires is_staff; map it to is_admin
    @property
    def is_staff(self):
        return self.is_admin

    def __str__(self):
        return self.name or self.phone_number

    @property
    def avatar_url(self):
        return self.avatar.url if self.avatar else None

    def mark_online(self):
        self.is_online = True
        self.save(update_fields=['is_online'])

    def mark_offline(self):
        self.is_online = False
        self.last_seen = timezone.now()
        self.save(update_fields=['is_online', 'last_seen'])


class Contact(models.Model):
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='contacts',
        verbose_name='المالك',
    )
    contact_user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='added_by',
        verbose_name='جهة الاتصال',
    )
    nickname = models.CharField(max_length=120, blank=True, verbose_name='الاسم المستعار')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'contacts'
        unique_together = ('owner', 'contact_user')
        verbose_name = 'جهة اتصال'
        verbose_name_plural = 'جهات الاتصال'
        ordering = ['nickname', 'contact_user__name']

    def __str__(self):
        label = self.nickname or self.contact_user.name or self.contact_user.phone_number
        return f'{self.owner} → {label}'


class BlockedUser(models.Model):
    blocker = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='blocking',
        verbose_name='المحظِر',
    )
    blocked = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='blocked_by',
        verbose_name='المحظور',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'blocked_users'
        unique_together = ('blocker', 'blocked')
        verbose_name = 'مستخدم محظور'
        verbose_name_plural = 'المستخدمون المحظورون'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.blocker} حظر {self.blocked}'


class InviteLink(models.Model):
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='invite_links',
        verbose_name='المالك',
    )
    token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    uses_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'invite_links'
        verbose_name = 'رابط دعوة'
        verbose_name_plural = 'روابط الدعوة'
        ordering = ['-created_at']

    def __str__(self):
        return f'دعوة {self.owner} ({self.uses_count} استخدام)'
