import 'package:dartz/dartz.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../datasources/conversation_remote_datasource.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  const ConversationRepositoryImpl(this._datasource);
  final ConversationRemoteDatasource _datasource;

  @override
  Future<Either<String, List<ConversationEntity>>> getConversations() async {
    try {
      return Right(await _datasource.getConversations());
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, ConversationEntity>> getConversation(String id) async {
    try {
      return Right(await _datasource.getConversation(id));
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, ConversationEntity>> createDirect(
      String userId) async {
    try {
      return Right(await _datasource.createDirect(userId));
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, ConversationEntity>> createGroup({
    required String name,
    required List<String> participantIds,
    String? avatarPath,
  }) async {
    try {
      return Right(await _datasource.createGroup(
        name: name,
        participantIds: participantIds,
        avatarPath: avatarPath,
      ));
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> archiveConversation(String id) async {
    try {
      await _datasource.archiveConversation(id);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> pinConversation(String id,
      {required bool pin}) async {
    try {
      await _datasource.pinConversation(id, pin: pin);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> deleteConversation(String id) async {
    try {
      await _datasource.deleteConversation(id);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> addGroupMember(
      String groupId, String userId) async {
    try {
      await _datasource.addGroupMember(groupId, userId);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, void>> removeGroupMember(
      String groupId, String userId) async {
    try {
      await _datasource.removeGroupMember(groupId, userId);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }
}
