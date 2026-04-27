import 'package:dartz/dartz.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';

class MessageRepositoryImpl implements MessageRepository {
  const MessageRepositoryImpl(this._datasource);
  final MessageRemoteDatasource _datasource;

  @override
  Future<Either<String, List<MessageEntity>>> getMessages(
    String conversationId, {
    String? beforeId,
    int limit = 30,
  }) async {
    try {
      return Right(await _datasource.getMessages(
        conversationId,
        beforeId: beforeId,
        limit: limit,
      ));
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, MessageEntity>> sendMessage({
    required String conversationId,
    required String content,
    required MessageType type,
    String? replyToId,
    String? mediaPath,
  }) async {
    try {
      return Right(await _datasource.sendMessage(
        conversationId: conversationId,
        content: content,
        type: type.name,
        replyToId: replyToId,
        mediaPath: mediaPath,
      ));
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> deleteMessage(String messageId) async {
    try {
      await _datasource.deleteMessage(messageId);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> markRead(String conversationId) async {
    try {
      await _datasource.markRead(conversationId);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }
}
