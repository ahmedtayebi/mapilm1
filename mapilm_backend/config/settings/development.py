from .base import *  # noqa: F401, F403

DEBUG = True

# INSTALLED_APPS += ['django_extensions']  # noqa: F405  # install separately if needed

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

CORS_ALLOW_ALL_ORIGINS = True

LOGGING['root']['level'] = 'DEBUG'  # noqa: F405
