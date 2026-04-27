from django.urls import path

from .views import (
    AddMemberView,
    ArchiveConversationView,
    ConversationDetailView,
    ConversationListView,
    CreateGroupView,
    CreatePrivateConversationView,
    GroupMembersView,
    RemoveMemberView,
    UpdateGroupView,
)

# Mounted at /api/v1/conversations/
urlpatterns = [
    path('', ConversationListView.as_view(), name='conversation-list'),
    path('private/', CreatePrivateConversationView.as_view(), name='conversation-create-private'),
    path('group/', CreateGroupView.as_view(), name='conversation-create-group'),
    path('<uuid:pk>/', ConversationDetailView.as_view(), name='conversation-detail'),
    path('<uuid:pk>/archive/', ArchiveConversationView.as_view(), name='conversation-archive'),
    path('<uuid:pk>/members/', GroupMembersView.as_view(), name='conversation-members'),
    path('<uuid:pk>/add-member/', AddMemberView.as_view(), name='conversation-add-member'),
    path('<uuid:pk>/remove-member/<uuid:user_id>/', RemoveMemberView.as_view(), name='conversation-remove-member'),
    path('<uuid:pk>/update/', UpdateGroupView.as_view(), name='conversation-update-group'),
]
