from django.urls import path
from .views import RegisterFCMTokenView, NotificationListView, mark_notifications_read

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification-list'),
    path('fcm-token/', RegisterFCMTokenView.as_view(), name='fcm-token'),
    path('mark-read/', mark_notifications_read, name='notifications-mark-read'),
]
