import uuid
from cloudinary.models import CloudinaryField
from django.db import models
from apps.users.models import User
from apps.conversations.models import Conversation


class Message(models.Model):
    TYPE_TEXT = 'text'
    TYPE_IMAGE = 'image'
    TYPE_VOICE = 'voice'
    TYPE_CHOICES = [
        (TYPE_TEXT, 'نص'),
        (TYPE_IMAGE, 'صورة'),
        (TYPE_VOICE, 'صوت'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages',
        verbose_name='المحادثة',
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='sent_messages',
        verbose_name='المرسِل',
    )
    type = models.CharField(
        max_length=10,
        choices=TYPE_CHOICES,
        default=TYPE_TEXT,
        verbose_name='النوع',
    )
    content = models.TextField(
        blank=True,
        verbose_name='المحتوى',
        help_text='النص مشفّر (AES-256)',
    )
    is_deleted = models.BooleanField(default=False, verbose_name='محذوف')
    reply_to = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='replies',
        verbose_name='ردّ على',
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'messages'
        verbose_name = 'رسالة'
        verbose_name_plural = 'الرسائل'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['conversation', '-created_at']),
            models.Index(fields=['sender', '-created_at']),
        ]

    def __str__(self):
        if self.is_deleted:
            return f'[محذوفة] {self.sender}'
        preview = self.content[:50] if self.type == self.TYPE_TEXT else f'[{self.get_type_display()}]'
        return f'{self.sender}: {preview}'

    def soft_delete(self):
        self.is_deleted = True
        self.content = ''
        self.save(update_fields=['is_deleted', 'content', 'updated_at'])


class MessageStatus(models.Model):
    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name='statuses',
        verbose_name='الرسالة',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='message_statuses',
        verbose_name='المستخدم',
    )
    is_delivered = models.BooleanField(default=False, verbose_name='مُسلَّمة')
    is_read = models.BooleanField(default=False, verbose_name='مقروءة')
    delivered_at = models.DateTimeField(null=True, blank=True, verbose_name='وقت التسليم')
    read_at = models.DateTimeField(null=True, blank=True, verbose_name='وقت القراءة')

    class Meta:
        db_table = 'message_statuses'
        unique_together = ('message', 'user')
        verbose_name = 'حالة رسالة'
        verbose_name_plural = 'حالات الرسائل'
        ordering = ['message', 'user']

    def __str__(self):
        state = 'مقروءة' if self.is_read else ('مُسلَّمة' if self.is_delivered else 'مُرسَلة')
        return f'{self.message_id} → {self.user} [{state}]'

    def mark_delivered(self):
        from django.utils import timezone
        if not self.is_delivered:
            self.is_delivered = True
            self.delivered_at = timezone.now()
            self.save(update_fields=['is_delivered', 'delivered_at'])

    def mark_read(self):
        from django.utils import timezone
        now = timezone.now()
        fields = []
        if not self.is_delivered:
            self.is_delivered = True
            self.delivered_at = now
            fields += ['is_delivered', 'delivered_at']
        if not self.is_read:
            self.is_read = True
            self.read_at = now
            fields += ['is_read', 'read_at']
        if fields:
            self.save(update_fields=fields)


class Media(models.Model):
    FILE_TYPE_IMAGE = 'image'
    FILE_TYPE_VOICE = 'voice'
    FILE_TYPE_CHOICES = [
        (FILE_TYPE_IMAGE, 'صورة'),
        (FILE_TYPE_VOICE, 'صوت'),
    ]

    message = models.OneToOneField(
        Message,
        on_delete=models.CASCADE,
        related_name='media',
        verbose_name='الرسالة',
    )
    file = CloudinaryField(
        'ملف الوسائط',
        folder='mapilm/media',
        resource_type='auto',
    )
    file_type = models.CharField(
        max_length=10,
        choices=FILE_TYPE_CHOICES,
        verbose_name='نوع الملف',
    )
    file_size = models.PositiveIntegerField(
        default=0,
        verbose_name='حجم الملف (bytes)',
    )
    duration = models.FloatField(
        null=True,
        blank=True,
        verbose_name='المدة (ثانية)',
        help_text='للرسائل الصوتية فقط',
    )
    thumbnail = CloudinaryField(
        'الصورة المصغّرة',
        folder='mapilm/thumbnails',
        blank=True,
        null=True,
    )

    class Meta:
        db_table = 'media'
        verbose_name = 'وسائط'
        verbose_name_plural = 'الوسائط'

    def __str__(self):
        size_kb = round(self.file_size / 1024, 1)
        return f'{self.get_file_type_display()} ({size_kb} KB) — رسالة {self.message_id}'

    @property
    def file_url(self):
        return self.file.url if self.file else None

    @property
    def thumbnail_url(self):
        return self.thumbnail.url if self.thumbnail else None
