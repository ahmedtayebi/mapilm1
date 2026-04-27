import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppConfig {
  // ── Base URLs ──────────────────────────────────────────────────────────────
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://your-backend.railway.app/api/v1';

  static String get wsUrl =>
      dotenv.env['WS_URL'] ?? 'wss://your-backend.railway.app/ws';

  static String get inviteBaseUrl =>
      dotenv.env['INVITE_BASE_URL'] ?? 'https://mapilm.app/invite';

  // ── Auth ───────────────────────────────────────────────────────────────────
  static const String authVerify = '/auth/verify/';
  static const String authRefresh = '/auth/refresh/';
  static const String authLogout = '/auth/logout/';

  // ── Users ──────────────────────────────────────────────────────────────────
  static const String usersMe = '/users/me/';
  static const String usersUpdate = '/users/profile/update/';
  static const String usersSearch = '/users/search/';
  static const String usersFcm = '/users/fcm-token/';

  // ── Contacts ───────────────────────────────────────────────────────────────
  static const String contacts = '/contacts/';
  static const String contactsAdd = '/contacts/add/';
  static String contactsBlock(String userId) => '/contacts/block/$userId/';
  static String contactsUnblock(String userId) => '/contacts/unblock/$userId/';

  // ── Conversations ──────────────────────────────────────────────────────────
  static const String conversations = '/conversations/';
  static const String conversationsPrivate = '/conversations/private/';
  static const String conversationsGroup = '/conversations/group/';
  static String conversationDetail(String id) => '/conversations/$id/';
  static String conversationArchive(String id) => '/conversations/$id/archive/';
  static String conversationMembers(String id) => '/conversations/$id/members/';
  static String conversationAddMember(String id) => '/conversations/$id/add-member/';
  static String conversationRemoveMember(String convId, String userId) =>
      '/conversations/$convId/remove-member/$userId/';
  static String conversationUpdate(String id) => '/conversations/$id/update/';

  // ── Messages ───────────────────────────────────────────────────────────────
  static const String messagesList = '/messages/';
  static const String messagesSend = '/messages/send/';
  static const String messagesUpload = '/messages/upload-media/';
  static String messagesForConversation(String convId) => '/messages/$convId/';
  static String messageRead(String messageId) => '/messages/$messageId/read/';
  static String messageDelete(String messageId) => '/messages/$messageId/delete/';

  // ── Invite ─────────────────────────────────────────────────────────────────
  static const String inviteGenerate = '/invite/generate/';
  static String inviteUse(String token) => '/invite/$token/';

  // ── Notifications ──────────────────────────────────────────────────────────
  static const String notifications = '/notifications/';
  static const String notificationsFcm = '/notifications/fcm-token/';
  static const String notificationsMarkRead = '/notifications/mark-read/';

  // ── WebSocket paths ────────────────────────────────────────────────────────
  static String wsChatPath(String conversationId) => '/chat/$conversationId/';
}
