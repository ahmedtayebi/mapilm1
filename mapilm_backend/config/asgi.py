import os

import django
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

# Django must be fully set up before importing any app modules
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')
django.setup()

# HTTP handler — must be created after django.setup()
django_asgi_app = get_asgi_application()

# Import WebSocket URL patterns after setup so app registry is ready
from config.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        'http': django_asgi_app,
        'websocket': AllowedHostsOriginValidator(
            URLRouter(websocket_urlpatterns)
        ),
    }
)
