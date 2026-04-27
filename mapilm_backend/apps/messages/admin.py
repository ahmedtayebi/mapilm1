from django.contrib import admin
from django.utils.html import format_html

from .models import Media, Message, MessageStatus


class MessageStatusInline(admin.TabularInline):
    model = MessageStatus
    extra = 0
    readonly_fields = ('delivered_at', 'read_at')
    fields = ('user', 'is_delivered', 'is_read', 'delivered_at', 'read_at')
    raw_id_fields = ('user',)


class MediaInline(admin.StackedInline):
    model = Media
    extra = 0
    readonly_fields = ('file_preview', 'thumbnail_preview')
    fields = (
        'file', 'file_preview', 'file_type', 'file_size',
        'duration', 'thumbnail', 'thumbnail_preview',
    )

    @admin.display(description='معاينة الملف')
    def file_preview(self, obj):
        if obj.pk and obj.file_type == Media.FILE_TYPE_IMAGE and obj.file_url:
            return format_html(
                '<img src="{}" style="max-width:200px;max-height:200px;" />',
                obj.file_url,
            )
        return '—'

    @admin.display(description='معاينة الصورة المصغّرة')
    def thumbnail_preview(self, obj):
        if obj.pk and obj.thumbnail_url:
            return format_html(
                '<img src="{}" style="width:60px;height:60px;object-fit:cover;" />',
                obj.thumbnail_url,
            )
        return '—'


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'type', 'sender', 'conversation',
        'content_preview', 'is_deleted', 'created_at',
    )
    list_filter = ('type', 'is_deleted', 'created_at')
    search_fields = (
        'sender__phone_number', 'sender__name',
        'conversation__name',
        'content',
    )
    raw_id_fields = ('sender', 'conversation', 'reply_to')
    ordering = ('-created_at',)
    readonly_fields = ('id', 'created_at', 'updated_at')
    inlines = [MediaInline, MessageStatusInline]

    fieldsets = (
        ('المعرّف', {
            'fields': ('id',),
        }),
        ('المحتوى', {
            'fields': ('conversation', 'sender', 'type', 'content', 'reply_to', 'is_deleted'),
        }),
        ('التواريخ', {
            'fields': ('created_at', 'updated_at'),
        }),
    )

    @admin.display(description='المحتوى')
    def content_preview(self, obj):
        if obj.is_deleted:
            return format_html('<em style="color:gray;">محذوفة</em>')
        if obj.type == Message.TYPE_TEXT:
            return obj.content[:60] + ('…' if len(obj.content) > 60 else '')
        return format_html('<em>[{}]</em>', obj.get_type_display())


@admin.register(MessageStatus)
class MessageStatusAdmin(admin.ModelAdmin):
    list_display = (
        'message', 'user', 'is_delivered', 'is_read', 'delivered_at', 'read_at',
    )
    list_filter = ('is_delivered', 'is_read')
    search_fields = ('user__phone_number', 'user__name')
    raw_id_fields = ('message', 'user')
    ordering = ('-message__created_at',)
    readonly_fields = ('delivered_at', 'read_at')


@admin.register(Media)
class MediaAdmin(admin.ModelAdmin):
    list_display = ('message', 'file_type', 'file_size_display', 'duration')
    list_filter = ('file_type',)
    search_fields = ('message__sender__phone_number', 'message__sender__name')
    raw_id_fields = ('message',)

    @admin.display(description='الحجم')
    def file_size_display(self, obj):
        kb = obj.file_size / 1024
        if kb > 1024:
            return f'{kb / 1024:.1f} MB'
        return f'{kb:.1f} KB'
