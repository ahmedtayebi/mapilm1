import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/websocket_client.dart';
import '../../data/datasources/message_remote_datasource.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return MessageRepositoryImpl(MessageRemoteDatasourceImpl(client));
});

final messagesProvider = AsyncNotifierProviderFamily<MessagesNotifier,
    List<MessageEntity>, String>(MessagesNotifier.new);

class MessagesNotifier
    extends FamilyAsyncNotifier<List<MessageEntity>, String> {
  late String _conversationId;

  @override
  Future<List<MessageEntity>> build(String arg) async {
    _conversationId = arg;
    final repo = ref.watch(messageRepositoryProvider);
    final result = await repo.getMessages(_conversationId);
    final messages =
        result.fold((e) => throw Exception(e), (list) => list);

    _connectWs();
    return messages;
  }

  Timer? _typingAutoStopTimer;

  void _connectWs() {
    final wsClient = ref.read(wsClientProvider);
    wsClient.connect(_conversationId);
    wsClient.messages.listen((data) {
      final type = data['type'] as String?;
      if (type == 'chat_message') {
        final msg = MessageModel.fromWs(data);
        state.whenData(
          (messages) => state = AsyncData([msg, ...messages]),
        );
        // Reset typing when a message arrives
        ref.read(typingProvider(_conversationId).notifier).state = false;
        _typingAutoStopTimer?.cancel();
      } else if (type == 'typing_start') {
        ref.read(typingProvider(_conversationId).notifier).state = true;
        _typingAutoStopTimer?.cancel();
        _typingAutoStopTimer = Timer(const Duration(seconds: 3), () {
          ref.read(typingProvider(_conversationId).notifier).state = false;
        });
      } else if (type == 'typing_stop') {
        _typingAutoStopTimer?.cancel();
        ref.read(typingProvider(_conversationId).notifier).state = false;
      } else if (type == 'message_deleted') {
        final msgId = data['message_id'] as String;
        state.whenData(
          (messages) => state = AsyncData(
            messages.map((m) {
              if (m.id != msgId) return m;
              return MessageEntity(
                id: m.id,
                conversationId: m.conversationId,
                senderId: m.senderId,
                type: MessageType.deleted,
                status: m.status,
                sentAt: m.sentAt,
                isDeleted: true,
              );
            }).toList(),
          ),
        );
      } else if (type == 'read_receipt') {
        final readById = data['user_id'] as String;
        state.whenData(
          (messages) => state = AsyncData(
            messages.map((m) {
              if (m.status == MessageStatus.seen ||
                  m.senderId == readById) return m;
              return MessageEntity(
                id: m.id,
                conversationId: m.conversationId,
                senderId: m.senderId,
                type: m.type,
                status: MessageStatus.seen,
                sentAt: m.sentAt,
                content: m.content,
                mediaUrl: m.mediaUrl,
                senderName: m.senderName,
                senderAvatar: m.senderAvatar,
              );
            }).toList(),
          ),
        );
      }
    });
  }

  Future<void> loadMore() async {
    final currentMessages = state.valueOrNull;
    if (currentMessages == null || currentMessages.isEmpty) return;
    final repo = ref.read(messageRepositoryProvider);
    final result = await repo.getMessages(
      _conversationId,
      beforeId: currentMessages.last.id,
    );
    result.fold(
      (e) => null,
      (older) => state.whenData(
        (messages) => state = AsyncData([...messages, ...older]),
      ),
    );
  }

  Future<void> sendText(String content, {String? replyToId}) async {
    final repo = ref.read(messageRepositoryProvider);
    final result = await repo.sendMessage(
      conversationId: _conversationId,
      content: content,
      type: MessageType.text,
      replyToId: replyToId,
    );
    result.fold(
      (e) => null,
      (msg) => state.whenData(
        (messages) => state = AsyncData([msg, ...messages]),
      ),
    );
  }

  Future<void> sendMedia(String mediaPath, MessageType type) async {
    final repo = ref.read(messageRepositoryProvider);
    final result = await repo.sendMessage(
      conversationId: _conversationId,
      content: '',
      type: type,
      mediaPath: mediaPath,
    );
    result.fold(
      (e) => null,
      (msg) => state.whenData(
        (messages) => state = AsyncData([msg, ...messages]),
      ),
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final repo = ref.read(messageRepositoryProvider);
    await repo.deleteMessage(messageId);
  }

  void sendTyping(bool isTyping) {
    ref.read(wsClientProvider).sendTyping(isTyping);
  }
}

// Typing state
final typingProvider =
    StateProvider.family<bool, String>((ref, conversationId) => false);
