from django.contrib import admin
from django.http import JsonResponse
from django.urls import path, include
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)


def health_check(request):
    return JsonResponse({"status": "ok"})

api_v1_patterns = [
    # ── Auth ──────────────────────────────────────────────────────────
    path('auth/', include('apps.users.urls')),

    # ── Users ──────────────────────────────────────────────────────────
    path('users/', include('apps.users.urls_users')),

    # ── Contacts & blocking ────────────────────────────────────────────
    path('contacts/', include('apps.users.urls_contacts')),

    # ── Invite links ───────────────────────────────────────────────────
    path('invite/', include('apps.users.urls_invite')),

    # ── Conversations ─────────────────────────────────────────────────
    path('conversations/', include('apps.conversations.urls')),

    # ── Messages ──────────────────────────────────────────────────────
    path('messages/', include('apps.messages.urls')),

    # ── Notifications ─────────────────────────────────────────────────
    path('notifications/', include('apps.notifications.urls')),
]

urlpatterns = [
    path('health/', health_check, name='health-check'),
    path('admin/', admin.site.urls),
    path('api/v1/', include(api_v1_patterns)),

    # ── API docs ──────────────────────────────────────────────────────
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]
