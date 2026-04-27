import 'package:equatable/equatable.dart';

enum MessageType { text, image, voice, video, document, location, deleted }
enum MessageStatus { sending, sent, delivered, seen, failed }

class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.status,
    required this.sentAt,
    this.content,
    this.mediaUrl,
    this.mediaDuration,
    this.replyTo,
    this.senderName,
    this.senderAvatar,
    this.isDeleted = false,
    this.isEdited = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final MessageStatus status;
  final DateTime sentAt;
  final String? content;
  final String? mediaUrl;
  final int? mediaDuration;
  final MessageEntity? replyTo;
  final String? senderName;
  final String? senderAvatar;
  final bool isDeleted;
  final bool isEdited;

  bool isFromMe(String currentUserId) => senderId == currentUserId;

  @override
  List<Object?> get props => [
        id, conversationId, senderId, type, status, sentAt,
        content, mediaUrl, mediaDuration, replyTo, senderName,
        senderAvatar, isDeleted, isEdited,
      ];
}
