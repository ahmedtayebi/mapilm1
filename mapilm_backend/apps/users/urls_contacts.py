from django.urls import path

from .views import (
    AddContactView,
    BlockUserView,
    ContactListView,
    UnblockUserView,
)

# Mounted at /api/v1/contacts/
urlpatterns = [
    path('', ContactListView.as_view(), name='contact-list'),
    path('add/', AddContactView.as_view(), name='contact-add'),
    path('block/<uuid:user_id>/', BlockUserView.as_view(), name='contact-block'),
    path('unblock/<uuid:user_id>/', UnblockUserView.as_view(), name='contact-unblock'),
]
