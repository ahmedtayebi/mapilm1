from django.urls import path

from .views import GenerateInviteLinkView, UseInviteLinkView

# Mounted at /api/v1/invite/
urlpatterns = [
    path('generate/', GenerateInviteLinkView.as_view(), name='invite-generate'),
    path('<uuid:token>/', UseInviteLinkView.as_view(), name='invite-use'),
]
