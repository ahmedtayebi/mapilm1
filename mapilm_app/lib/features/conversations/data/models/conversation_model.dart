import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/conversation_entity.dart';

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.type,
    required super.participants,
    super.name,
    super.avatarUrl,
    super.lastMessage,
    super.lastMessageAt,
    super.unreadCount,
    super.isArchived,
    super.isPinned,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'direct';
    return ConversationModel(
      id: json['id'] as String,
      type: typeStr == 'group'
          ? ConversationType.group
          : ConversationType.direct,
      participants: (json['participants'] as List<dynamic>)
          .map((p) => UserModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isArchived: json['is_archived'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }
}
