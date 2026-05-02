import 'package:dio/dio.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDatasource {
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    String? beforeId,
    int limit,
  });
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    required String type,
    String? replyToId,
    String? mediaPath,
  });
  Future<void> deleteMessage(String messageId);
  Future<void> markRead(String conversationId);
}

class MessageRemoteDatasourceImpl implements MessageRemoteDatasource {
  const MessageRemoteDatasourceImpl(this._client);
  final DioClient _client;

  // MessageListView returns {results: [...]} when paginated, else a list.
  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List<dynamic>;
    }
    return const [];
  }

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    String? beforeId,
    int limit = 30,
  }) async {
    // Backend: GET /messages/<conversation_id>/?before_id=...&limit=...
    final res = await _client.get<dynamic>(
      AppConfig.messagesForConversation(conversationId),
      queryParameters: {
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
    return _unwrapList(res.data)
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    required String type,
    String? replyToId,
    String? mediaPath,
  }) async {
    if (mediaPath != null) {
      // Backend: POST /messages/upload-media/  multipart
      final formData = FormData.fromMap({
        'conversation_id': conversationId,
        'message_type': type,
        if (content.isNotEmpty) 'content': content,
        if (replyToId != null) 'reply_to_id': replyToId,
        'media': await MultipartFile.fromFile(mediaPath),
      });
      final res = await _client.upload<Map<String, dynamic>>(
        AppConfig.messagesUpload,
        formData,
      );
      return MessageModel.fromJson(res.data!);
    }

    // Backend: POST /messages/send/  json
    final res = await _client.post<Map<String, dynamic>>(
      AppConfig.messagesSend,
      data: {
        'conversation_id': conversationId,
        'content': content,
        'message_type': type,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
    return MessageModel.fromJson(res.data!);
  }

  @override
  Future<void> deleteMessage(String messageId) =>
      // Backend uses POST (not DELETE) for delete — soft-delete semantics.
      _client.post(AppConfig.messageDelete(messageId));

  @override
  Future<void> markRead(String conversationId) async {
    // Backend has no bulk "mark conversation read" endpoint; per-message reads
    // flow through the WebSocket `message.read` event. This REST path is left
    // as a no-op so callers don't crash, but real read receipts come from WS.
    return;
  }
}
