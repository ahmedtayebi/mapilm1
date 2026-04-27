import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/conversation_model.dart';

abstract class ConversationRemoteDatasource {
  Future<List<ConversationModel>> getConversations();
  Future<ConversationModel> getConversation(String id);
  Future<ConversationModel> createDirect(String userId);
  Future<ConversationModel> createGroup({
    required String name,
    required List<String> participantIds,
    String? avatarPath,
  });
  Future<void> archiveConversation(String id);
  Future<void> pinConversation(String id, {required bool pin});
  Future<void> deleteConversation(String id);
  Future<void> addGroupMember(String groupId, String userId);
  Future<void> removeGroupMember(String groupId, String userId);
}

class ConversationRemoteDatasourceImpl
    implements ConversationRemoteDatasource {
  const ConversationRemoteDatasourceImpl(this._client);
  final DioClient _client;

  @override
  Future<List<ConversationModel>> getConversations() async {
    final res = await _client.get<List<dynamic>>('/conversations/');
    return (res.data ?? [])
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ConversationModel> getConversation(String id) async {
    final res =
        await _client.get<Map<String, dynamic>>('/conversations/$id/');
    return ConversationModel.fromJson(res.data!);
  }

  @override
  Future<ConversationModel> createDirect(String userId) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/conversations/',
      data: {'type': 'direct', 'participant_id': userId},
    );
    return ConversationModel.fromJson(res.data!);
  }

  @override
  Future<ConversationModel> createGroup({
    required String name,
    required List<String> participantIds,
    String? avatarPath,
  }) async {
    final formData = FormData.fromMap({
      'type': 'group',
      'name': name,
      'participant_ids': participantIds,
      if (avatarPath != null)
        'avatar': await MultipartFile.fromFile(avatarPath),
    });
    final res = await _client.upload<Map<String, dynamic>>(
      '/conversations/',
      formData,
    );
    return ConversationModel.fromJson(res.data!);
  }

  @override
  Future<void> archiveConversation(String id) =>
      _client.patch('/conversations/$id/', data: {'is_archived': true});

  @override
  Future<void> pinConversation(String id, {required bool pin}) =>
      _client.patch('/conversations/$id/', data: {'is_pinned': pin});

  @override
  Future<void> deleteConversation(String id) =>
      _client.delete('/conversations/$id/');

  @override
  Future<void> addGroupMember(String groupId, String userId) =>
      _client.post('/conversations/$groupId/members/', data: {'user_id': userId});

  @override
  Future<void> removeGroupMember(String groupId, String userId) =>
      _client.delete('/conversations/$groupId/members/$userId/');
}
