import 'package:dartz/dartz.dart';
import '../entities/message_entity.dart';

abstract class MessageRepository {
  Future<Either<String, List<MessageEntity>>> getMessages(
    String conversationId, {
    String? beforeId,
    int limit,
  });
  Future<Either<String, MessageEntity>> sendMessage({
    required String conversationId,
    required String content,
    required MessageType type,
    String? replyToId,
    String? mediaPath,
  });
  Future<Either<String, void>> deleteMessage(String messageId);
  Future<Either<String, void>> markRead(String conversationId);
}
