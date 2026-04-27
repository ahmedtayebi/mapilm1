import logging

from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

logger = logging.getLogger(__name__)


class SafeAnonRateThrottle(AnonRateThrottle):
    def allow_request(self, request, view):
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning('AnonRateThrottle cache error — allowing request', exc_info=True)
            return True


class SafeUserRateThrottle(UserRateThrottle):
    def allow_request(self, request, view):
        try:
            return super().allow_request(request, view)
        except Exception:
            logger.warning('UserRateThrottle cache error — allowing request', exc_info=True)
            return True
