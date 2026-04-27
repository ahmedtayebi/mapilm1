import 'package:dartz/dartz.dart';
import '../entities/conversation_entity.dart';

abstract class ConversationRepository {
  Future<Either<String, List<ConversationEntity>>> getConversations();
  Future<Either<String, ConversationEntity>> getConversation(String id);
  Future<Either<String, ConversationEntity>> createDirect(String userId);
  Future<Either<String, ConversationEntity>> createGroup({
    required String name,
    required List<String> participantIds,
    String? avatarPath,
  });
  Future<Either<String, void>> archiveConversation(String id);
  Future<Either<String, void>> pinConversation(String id, {required bool pin});
  Future<Either<String, void>> deleteConversation(String id);
  Future<Either<String, void>> addGroupMember(String groupId, String userId);
  Future<Either<String, void>> removeGroupMember(String groupId, String userId);
}
