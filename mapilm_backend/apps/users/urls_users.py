from django.urls import path

from .views import (
    GetMyProfileView,
    SearchUserView,
    UpdateFCMTokenView,
    UpdateProfileView,
)

# Mounted at /api/v1/users/
urlpatterns = [
    path('me/', GetMyProfileView.as_view(), name='user-me'),
    path('profile/update/', UpdateProfileView.as_view(), name='user-profile-update'),
    path('search/', SearchUserView.as_view(), name='user-search'),
    path('fcm-token/', UpdateFCMTokenView.as_view(), name='user-fcm-token'),
]
