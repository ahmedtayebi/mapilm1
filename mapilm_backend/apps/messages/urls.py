from django.urls import path

from .views import (
    DeleteMessageView,
    MarkReadView,
    MessageListView,
    SendMessageView,
    UploadMediaView,
)

# Mounted at /api/v1/messages/
urlpatterns = [
    path('send/', SendMessageView.as_view(), name='message-send'),
    path('upload-media/', UploadMediaView.as_view(), name='message-upload-media'),
    path('<uuid:conversation_id>/', MessageListView.as_view(), name='message-list'),
    path('<uuid:pk>/read/', MarkReadView.as_view(), name='message-mark-read'),
    path('<uuid:pk>/delete/', DeleteMessageView.as_view(), name='message-delete'),
]
