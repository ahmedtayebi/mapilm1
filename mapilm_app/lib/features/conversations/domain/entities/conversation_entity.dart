import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/user_entity.dart';

enum ConversationType { direct, group }

class ConversationEntity extends Equatable {
  const ConversationEntity({
    required this.id,
    required this.type,
    required this.participants,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isPinned = false,
  });

  final String id;
  final ConversationType type;
  final List<UserEntity> participants;
  final String? name;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isArchived;
  final bool isPinned;

  bool get isGroup => type == ConversationType.group;
  bool get hasUnread => unreadCount > 0;

  String displayName(String currentUserId) {
    if (name != null) return name!;
    final other = participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => participants.first,
    );
    return other.name ?? other.phone;
  }

  String? displayAvatar(String currentUserId) {
    if (avatarUrl != null) return avatarUrl;
    if (!isGroup) {
      final other = participants.firstWhere(
        (p) => p.id != currentUserId,
        orElse: () => participants.first,
      );
      return other.avatarUrl;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id, type, participants, name, avatarUrl,
        lastMessage, lastMessageAt, unreadCount, isArchived, isPinned,
      ];
}
