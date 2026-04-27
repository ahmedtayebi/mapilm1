from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html

from .models import BlockedUser, Contact, InviteLink, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = (
        'phone_number', 'name', 'avatar_preview',
        'is_online', 'is_active', 'is_admin', 'created_at',
    )
    list_filter = ('is_active', 'is_admin', 'is_online')
    search_fields = ('phone_number', 'name', 'firebase_uid')
    ordering = ('-created_at',)
    readonly_fields = ('id', 'firebase_uid', 'created_at', 'last_seen', 'avatar_preview')

    fieldsets = (
        ('المعرّف', {
            'fields': ('id', 'firebase_uid', 'phone_number'),
        }),
        ('المعلومات الشخصية', {
            'fields': ('name', 'avatar', 'avatar_preview', 'status'),
        }),
        ('الحضور', {
            'fields': ('is_online', 'last_seen', 'fcm_token'),
        }),
        ('الصلاحيات', {
            'fields': ('is_active', 'is_admin', 'is_superuser', 'groups', 'user_permissions'),
        }),
        ('التواريخ', {
            'fields': ('created_at',),
        }),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('phone_number', 'firebase_uid', 'name', 'is_active', 'is_admin'),
        }),
    )

    # BaseUserAdmin expects these
    filter_horizontal = ('groups', 'user_permissions')

    @admin.display(description='الصورة')
    def avatar_preview(self, obj):
        if obj.avatar_url:
            return format_html(
                '<img src="{}" style="width:40px;height:40px;border-radius:50%;object-fit:cover;" />',
                obj.avatar_url,
            )
        return '—'


@admin.register(Contact)
class ContactAdmin(admin.ModelAdmin):
    list_display = ('owner', 'contact_user', 'nickname', 'created_at')
    list_filter = ('created_at',)
    search_fields = (
        'owner__phone_number', 'owner__name',
        'contact_user__phone_number', 'contact_user__name',
        'nickname',
    )
    raw_id_fields = ('owner', 'contact_user')
    ordering = ('-created_at',)
    readonly_fields = ('created_at',)


@admin.register(BlockedUser)
class BlockedUserAdmin(admin.ModelAdmin):
    list_display = ('blocker', 'blocked', 'created_at')
    list_filter = ('created_at',)
    search_fields = (
        'blocker__phone_number', 'blocker__name',
        'blocked__phone_number', 'blocked__name',
    )
    raw_id_fields = ('blocker', 'blocked')
    ordering = ('-created_at',)
    readonly_fields = ('created_at',)


@admin.register(InviteLink)
class InviteLinkAdmin(admin.ModelAdmin):
    list_display = ('owner', 'token', 'uses_count', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('owner__phone_number', 'owner__name', 'token')
    raw_id_fields = ('owner',)
    ordering = ('-created_at',)
    readonly_fields = ('token', 'created_at')
