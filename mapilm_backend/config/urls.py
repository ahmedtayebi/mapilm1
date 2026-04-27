from django.contrib import admin
from django.http import JsonResponse
from django.urls import path, include


def health_check(request):
    return JsonResponse({"status": "ok"})


api_v1_patterns = [
    path('auth/', include('apps.users.urls')),
    path('users/', include('apps.users.urls_users')),
    path('contacts/', include('apps.users.urls_contacts')),
    path('invite/', include('apps.users.urls_invite')),
    path('conversations/', include('apps.conversations.urls')),
    path('messages/', include('apps.messages.urls')),
    path('notifications/', include('apps.notifications.urls')),
]

urlpatterns = [
    path('health/', health_check, name='health-check'),
    path('admin/', admin.site.urls),
    path('api/v1/', include(api_v1_patterns)),
]
