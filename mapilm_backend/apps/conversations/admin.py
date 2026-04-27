from django.contrib import admin
from django.utils.html import format_html

from .models import Conversation, ConversationMember


class ConversationMemberInline(admin.TabularInline):
    model = ConversationMember
    extra = 0
    readonly_fields = ('joined_at', 'last_read_at')
    fields = ('user', 'role', 'is_muted', 'joined_at', 'last_read_at')
    raw_id_fields = ('user',)


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'type', 'name', 'avatar_preview',
        'created_by', 'is_archived', 'member_count', 'created_at', 'updated_at',
    )
    list_filter = ('type', 'is_archived', 'created_at')
    search_fields = ('name', 'created_by__phone_number', 'created_by__name')
    raw_id_fields = ('created_by',)
    ordering = ('-updated_at',)
    readonly_fields = ('id', 'created_at', 'updated_at', 'avatar_preview')
    inlines = [ConversationMemberInline]

    fieldsets = (
        ('المعرّف', {
            'fields': ('id',),
        }),
        ('المعلومات', {
            'fields': ('type', 'name', 'avatar', 'avatar_preview', 'created_by', 'is_archived'),
        }),
        ('التواريخ', {
            'fields': ('created_at', 'updated_at'),
        }),
    )

    @admin.display(description='الصورة')
    def avatar_preview(self, obj):
        if obj.avatar_url:
            return format_html(
                '<img src="{}" style="width:40px;height:40px;border-radius:8px;object-fit:cover;" />',
                obj.avatar_url,
            )
        return '—'

    @admin.display(description='عدد الأعضاء')
    def member_count(self, obj):
        return obj.memberships.count()


@admin.register(ConversationMember)
class ConversationMemberAdmin(admin.ModelAdmin):
    list_display = (
        'user', 'conversation', 'role', 'is_muted', 'joined_at', 'last_read_at',
    )
    list_filter = ('role', 'is_muted', 'joined_at')
    search_fields = (
        'user__phone_number', 'user__name',
        'conversation__name',
    )
    raw_id_fields = ('user', 'conversation')
    ordering = ('-joined_at',)
    readonly_fields = ('joined_at',)
