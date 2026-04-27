import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/conversation_remote_datasource.dart';
import '../../data/repositories/conversation_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  final datasource = ConversationRemoteDatasourceImpl(client);
  return ConversationRepositoryImpl(datasource);
});

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ConversationEntity>>(
  ConversationsNotifier.new,
);

class ConversationsNotifier
    extends AsyncNotifier<List<ConversationEntity>> {
  @override
  Future<List<ConversationEntity>> build() async {
    final repo = ref.watch(conversationRepositoryProvider);
    final result = await repo.getConversations();
    return result.fold((e) => throw Exception(e), (list) => list);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(conversationRepositoryProvider);
      final result = await repo.getConversations();
      return result.fold((e) => throw Exception(e), (list) => list);
    });
  }

  void updateLastMessage({
    required String conversationId,
    required String message,
    required DateTime sentAt,
  }) {
    state.whenData((conversations) {
      state = AsyncData(
        conversations.map((c) {
          if (c.id != conversationId) return c;
          return ConversationEntity(
            id: c.id,
            type: c.type,
            participants: c.participants,
            name: c.name,
            avatarUrl: c.avatarUrl,
            lastMessage: message,
            lastMessageAt: sentAt,
            unreadCount: c.unreadCount + 1,
            isArchived: c.isArchived,
            isPinned: c.isPinned,
          );
        }).toList()
          ..sort((a, b) {
            final aTime = a.lastMessageAt ?? DateTime(2000);
            final bTime = b.lastMessageAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          }),
      );
    });
  }

  void clearUnread(String conversationId) {
    state.whenData((conversations) {
      state = AsyncData(
        conversations.map((c) {
          if (c.id != conversationId) return c;
          return ConversationEntity(
            id: c.id,
            type: c.type,
            participants: c.participants,
            name: c.name,
            avatarUrl: c.avatarUrl,
            lastMessage: c.lastMessage,
            lastMessageAt: c.lastMessageAt,
            unreadCount: 0,
            isArchived: c.isArchived,
            isPinned: c.isPinned,
          );
        }).toList(),
      );
    });
  }

  Future<void> createGroup({
    required String name,
    required List<String> participantIds,
    String? avatarPath,
  }) async {
    final repo = ref.read(conversationRepositoryProvider);
    final result = await repo.createGroup(
      name: name,
      participantIds: participantIds,
      avatarPath: avatarPath,
    );
    result.fold(
      (e) => throw Exception(e),
      (conv) => state.whenData(
        (list) => state = AsyncData([conv, ...list]),
      ),
    );
  }
}
