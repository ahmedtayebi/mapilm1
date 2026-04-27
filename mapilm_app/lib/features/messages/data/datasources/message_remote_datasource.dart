import 'package:dio/dio.dart';
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

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    String? beforeId,
    int limit = 30,
  }) async {
    final res = await _client.get<List<dynamic>>(
      '/messages/',
      queryParameters: {
        'conversation_id': conversationId,
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
    return (res.data ?? [])
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
      final formData = FormData.fromMap({
        'conversation_id': conversationId,
        'message_type': type,
        if (replyToId != null) 'reply_to_id': replyToId,
        'media': await MultipartFile.fromFile(mediaPath),
      });
      final res = await _client.upload<Map<String, dynamic>>(
        '/messages/',
        formData,
      );
      return MessageModel.fromJson(res.data!);
    }

    final res = await _client.post<Map<String, dynamic>>(
      '/messages/',
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
      _client.delete('/messages/$messageId/');

  @override
  Future<void> markRead(String conversationId) =>
      _client.post('/messages/mark-read/', data: {'conversation_id': conversationId});
}
