from django.utils import timezone
from firebase_admin import messaging
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import User
from .models import NotificationLog


class RegisterFCMTokenView(APIView):
    def post(self, request):
        token = request.data.get('token', '').strip()
        if not token:
            return Response(
                {'detail': 'token مطلوب'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        User.objects.filter(id=request.user.id).update(fcm_token=token)
        return Response(status=status.HTTP_204_NO_CONTENT)


class NotificationListView(APIView):
    def get(self, request):
        logs = NotificationLog.objects.filter(
            recipient=request.user
        ).order_by('-created_at')[:50]

        data = [
            {
                'id': str(n.id),
                'title': n.title,
                'body': n.body,
                'data': n.data,
                'is_sent': n.is_sent,
                'sent_at': n.sent_at.isoformat() if n.sent_at else None,
                'created_at': n.created_at.isoformat(),
            }
            for n in logs
        ]
        return Response(data)


@api_view(['POST'])
def mark_notifications_read(request):
    # Notifications are logs; no read flag — this endpoint is kept for API compatibility
    return Response(status=status.HTTP_204_NO_CONTENT)


def send_push_notification(user: User, title: str, body: str, data: dict = None):
    data = data or {}
    log = NotificationLog.objects.create(
        recipient=user,
        title=title,
        body=body,
        data=data,
        is_sent=False,
    )

    if not user.fcm_token:
        return

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={str(k): str(v) for k, v in data.items()},
        token=user.fcm_token,
        android=messaging.AndroidConfig(priority='high'),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound='default', badge=1)
            )
        ),
    )

    try:
        messaging.send(message)
        log.is_sent = True
        log.sent_at = timezone.now()
        log.save(update_fields=['is_sent', 'sent_at'])
    except Exception:
        pass
