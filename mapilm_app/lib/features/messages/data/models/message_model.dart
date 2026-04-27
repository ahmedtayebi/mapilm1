import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.type,
    required super.status,
    required super.sentAt,
    super.content,
    super.mediaUrl,
    super.mediaDuration,
    super.replyTo,
    super.senderName,
    super.senderAvatar,
    super.isDeleted,
    super.isEdited,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['message_type'] as String? ?? 'text';
    final statusStr = json['status'] as String? ?? 'sent';

    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      type: _parseType(typeStr),
      status: _parseStatus(statusStr),
      sentAt: DateTime.parse(json['sent_at'] as String),
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaDuration: json['media_duration'] as int?,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      isEdited: json['is_edited'] as bool? ?? false,
      replyTo: json['reply_to'] != null
          ? MessageModel.fromJson(json['reply_to'] as Map<String, dynamic>)
          : null,
    );
  }

  factory MessageModel.fromWs(Map<String, dynamic> json) =>
      MessageModel.fromJson(json);

  static MessageType _parseType(String s) {
    return switch (s) {
      'image' => MessageType.image,
      'voice' => MessageType.voice,
      'video' => MessageType.video,
      'document' => MessageType.document,
      'location' => MessageType.location,
      'deleted' => MessageType.deleted,
      _ => MessageType.text,
    };
  }

  static MessageStatus _parseStatus(String s) {
    return switch (s) {
      'sending' => MessageStatus.sending,
      'delivered' => MessageStatus.delivered,
      'seen' => MessageStatus.seen,
      'failed' => MessageStatus.failed,
      _ => MessageStatus.sent,
    };
  }
}
