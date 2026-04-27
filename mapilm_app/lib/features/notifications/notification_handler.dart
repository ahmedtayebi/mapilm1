import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../shared/widgets/in_app_notification_banner.dart';
import '../conversations/presentation/widgets/conversation_tile.dart'
    show ChatScreenArgs, GroupChatScreenArgs;

/// Central class for routing notification events to the correct screen.
class NotificationHandler {
  NotificationHandler._();

  /// Called when a foreground message arrives — shows an in-app banner.
  static void handleForeground(
    RemoteMessage message, {
    required BuildContext context,
  }) {
    final data = message.data;
    final notification = message.notification;
    final senderName =
        data['sender_name'] as String? ?? notification?.title ?? 'Mapilm';
    final body =
        data['body'] as String? ?? notification?.body ?? '';

    InAppNotificationBanner.show(
      context,
      senderName: senderName,
      message: body,
      avatarUrl: data['sender_avatar'] as String?,
      onTap: () => navigate(data),
    );
  }

  /// Navigates to the appropriate screen from notification data.
  static void navigate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final convId = data['conversation_id'] as String?;
    if (convId == null) return;

    final router = globalRouter;
    if (router == null) return;

    switch (type) {
      case 'new_message':
        router.push(
          AppRoutes.chat,
          extra: ChatScreenArgs(
            conversationId: convId,
            participantName: data['sender_name'] as String? ?? '',
            participantAvatar: data['sender_avatar'] as String?,
          ),
        );
      case 'group_message':
        router.push(
          AppRoutes.groupChat,
          extra: GroupChatScreenArgs(conversationId: convId),
        );
    }
  }
}
