import uuid
from django.db import models
from apps.users.models import User


class NotificationLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='notification_logs',
        verbose_name='المستقبِل',
    )
    title = models.CharField(max_length=255, verbose_name='العنوان')
    body = models.CharField(max_length=1000, verbose_name='المحتوى')
    data = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='بيانات إضافية',
    )
    is_sent = models.BooleanField(default=False, verbose_name='أُرسلت')
    sent_at = models.DateTimeField(null=True, blank=True, verbose_name='وقت الإرسال')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notification_logs'
        verbose_name = 'سجل إشعار'
        verbose_name_plural = 'سجلات الإشعارات'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', '-created_at']),
            models.Index(fields=['is_sent', '-created_at']),
        ]

    def __str__(self):
        status = 'أُرسلت' if self.is_sent else 'لم تُرسَل'
        return f'[{status}] {self.title} → {self.recipient}'
