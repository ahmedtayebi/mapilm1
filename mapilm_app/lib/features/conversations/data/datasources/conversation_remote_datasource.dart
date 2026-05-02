import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
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

  // ConversationListView returns {results: [...], next, count} or a bare list
  // depending on pagination. Tolerate both shapes.
  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List<dynamic>;
    }
    return const [];
  }

  @override
  Future<List<ConversationModel>> getConversations() async {
    final res = await _client.get<dynamic>(AppConfig.conversations);
    return _unwrapList(res.data)
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ConversationModel> getConversation(String id) async {
    final res = await _client.get<Map<String, dynamic>>(
      AppConfig.conversationDetail(id),
    );
    return ConversationModel.fromJson(res.data!);
  }

  @override
  Future<ConversationModel> createDirect(String userId) async {
    // Backend: POST /conversations/private/  body: {user_id}
    final res = await _client.post<Map<String, dynamic>>(
      AppConfig.conversationsPrivate,
      data: {'user_id': userId},
    );
    return ConversationModel.fromJson(res.data!);
  }

  @override
  Future<ConversationModel> createGroup({
    required String name,
    required List<String> participantIds,
    String? avatarPath,
  }) async {
    // Backend: POST /conversations/group/  multipart {name, member_ids[], avatar}
    final formData = FormData.fromMap({
      'name': name,
      'member_ids': participantIds,
      if (avatarPath != null)
        'avatar': await MultipartFile.fromFile(avatarPath),
    });
    final res = await _client.upload<Map<String, dynamic>>(
      AppConfig.conversationsGroup,
      formData,
    );
    return ConversationModel.fromJson(res.data!);
  }

  @override
  Future<void> archiveConversation(String id) =>
      _client.post(AppConfig.conversationArchive(id));

  @override
  Future<void> pinConversation(String id, {required bool pin}) async {
    // Backend has no pin endpoint yet — UX-side flag only. No-op until the
    // backend exposes one (see also: ConversationListView ordering).
    return;
  }

  @override
  Future<void> deleteConversation(String id) {
    // Backend doesn't expose a hard-delete; "delete" from the client is
    // archive (matches the swipe-to-delete UX expectation).
    return _client.post(AppConfig.conversationArchive(id));
  }

  @override
  Future<void> addGroupMember(String groupId, String userId) =>
      _client.post(
        AppConfig.conversationAddMember(groupId),
        data: {'user_id': userId},
      );

  @override
  Future<void> removeGroupMember(String groupId, String userId) =>
      _client.delete(AppConfig.conversationRemoveMember(groupId, userId));
}
