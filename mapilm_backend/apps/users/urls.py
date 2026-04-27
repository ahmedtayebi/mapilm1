from django.urls import path

from .views import (
    LogoutView,
    RefreshTokenView,
    VerifyFirebaseTokenView,
)

# Mounted at /api/v1/auth/
urlpatterns = [
    path('verify/', VerifyFirebaseTokenView.as_view(), name='auth-verify'),
    path('refresh/', RefreshTokenView.as_view(), name='auth-refresh'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
]
