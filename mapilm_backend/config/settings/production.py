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

# ── Cache (Redis) ────────────────────────────────────────────────────────────
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': config('REDIS_URL', default='redis://localhost:6379'),
        'OPTIONS': {
            'socket_connect_timeout': 2,
            'socket_timeout': 2,
        },
    }
}

# ── Throttling ───────────────────────────────────────────────────────────────
# Override throttle classes with cache-safe versions. Django's RedisCache raises
# ConnectionError when Redis is unreachable; DRF's check_throttles() does not
# catch that, so an unhandled exception kills the worker (502). These subclasses
# swallow cache errors and allow the request instead of crashing.
REST_FRAMEWORK['DEFAULT_THROTTLE_CLASSES'] = [  # noqa: F405
    'config.throttles.SafeAnonRateThrottle',
    'config.throttles.SafeUserRateThrottle',
]

# ── Logging ─────────────────────────────────────────────────────────────────
LOGGING['root']['level'] = 'WARNING'  # noqa: F405
