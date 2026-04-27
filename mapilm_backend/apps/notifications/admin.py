from django.contrib import admin
from django.utils.html import format_html

from .models import NotificationLog


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'recipient', 'title', 'body_preview',
        'is_sent', 'sent_at', 'created_at',
    )
    list_filter = ('is_sent', 'created_at')
    search_fields = (
        'recipient__phone_number', 'recipient__name',
        'title', 'body',
    )
    raw_id_fields = ('recipient',)
    ordering = ('-created_at',)
    readonly_fields = ('id', 'created_at', 'sent_at')

    fieldsets = (
        ('المعرّف', {
            'fields': ('id',),
        }),
        ('المحتوى', {
            'fields': ('recipient', 'title', 'body', 'data'),
        }),
        ('الحالة', {
            'fields': ('is_sent', 'sent_at'),
        }),
        ('التواريخ', {
            'fields': ('created_at',),
        }),
    )

    @admin.display(description='المحتوى')
    def body_preview(self, obj):
        return obj.body[:80] + ('…' if len(obj.body) > 80 else '')

    actions = ['mark_as_sent']

    @admin.action(description='تحديد كـ "أُرسلت"')
    def mark_as_sent(self, request, queryset):
        from django.utils import timezone
        updated = queryset.filter(is_sent=False).update(
            is_sent=True, sent_at=timezone.now()
        )
        self.message_user(request, f'تم تحديث {updated} سجل.')
