from .base import *  # noqa: F401, F403
from decouple import config, Csv

DEBUG = False

ALLOWED_HOSTS = ['*']

# Strip drf_spectacular — docs are disabled in production; keeping it loaded
# consumes ~50-80 MB of schema introspection overhead on every worker boot.
INSTALLED_APPS = [app for app in INSTALLED_APPS if app != 'drf_spectacular']  # noqa: F405

REST_FRAMEWORK['DEFAULT_SCHEMA_CLASS'] = 'rest_framework.schemas.openapi.AutoSchema'  # noqa: F405

# ── Security ────────────────────────────────────────────────────────────────
SECURE_SSL_REDIRECT = False
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# ── CORS ────────────────────────────────────────────────────────────────────
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = config('CORS_ALLOWED_ORIGINS', cast=Csv(), default='')
CORS_ALLOW_CREDENTIALS = True

# ── Static files (WhiteNoise) ────────────────────────────────────────────────
STATIC_ROOT = BASE_DIR / 'staticfiles'  # noqa: F405
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# ── Media files (Cloudinary) ─────────────────────────────────────────────────
DEFAULT_FILE_STORAGE = 'cloudinary_storage.storage.MediaCloudinaryStorage'

# ── Cache ─────────────────────────────────────────────────────────────────────
# Use in-memory cache in production WSGI. Redis is only needed for Celery tasks;
# throttle counts don't need to survive worker restarts.
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}

# ── Channels (WSGI mode) ─────────────────────────────────────────────────────
# Running gunicorn WSGI — WebSocket consumers are inactive. Use in-memory
# channel layer so channels_redis never opens a Redis connection in this process.
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer',
    }
}

# ── Logging ─────────────────────────────────────────────────────────────────
LOGGING['root']['level'] = 'WARNING'  # noqa: F405
