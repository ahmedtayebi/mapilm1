import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/messages_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import 'chat_screen.dart' show ChatBackground, EmptyChatPlaceholder, MessageList, ScrollToBottomButton;
import '../../../conversations/presentation/providers/conversations_provider.dart';

// ── Args ───────────────────────────────────────────────────────────────────

class GroupChatScreenArgs {
  const GroupChatScreenArgs({required this.conversationId});
  final String conversationId;
}

// ── Sender Color Palette ───────────────────────────────────────────────────

const _kSenderColors = [
  Color(0xFF2038F5), Color(0xFF7C3AED), Color(0xFFDB2777),
  Color(0xFFD97706), Color(0xFF059669), Color(0xFF0891B2),
  Color(0xFFDC2626), Color(0xFF4F46E5),
];

Color _colorForSender(String senderId) {
  final hash = senderId.codeUnits.fold(0, (a, b) => a ^ b);
  return _kSenderColors[hash.abs() % _kSenderColors.length];
}

// ── Screen ─────────────────────────────────────────────────────────────────

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.args});
  final GroupChatScreenArgs args;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _scrollController = ScrollController();
  MessageEntity? _replyTo;
  bool _showScrollBtn = false;
  bool _hasNewMsg = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showBtn = _scrollController.offset > 300;
    if (showBtn != _showScrollBtn) {
      setState(() => _showScrollBtn = showBtn);
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref
          .read(messagesProvider(widget.args.conversationId).notifier)
          .loadMore();
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    setState(() {
      _showScrollBtn = false;
      _hasNewMsg = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';
    final messagesAsync =
        ref.watch(messagesProvider(widget.args.conversationId));
    final isTyping = ref.watch(typingProvider(widget.args.conversationId));
    final conversationsAsync = ref.watch(conversationsProvider);

    final group = conversationsAsync.valueOrNull?.firstWhere(
      (c) => c.id == widget.args.conversationId,
      orElse: () => conversationsAsync.valueOrNull!.first,
    );
    final groupName = group?.name ?? AppStrings.conversations;
    final membersCount = group?.participants.length ?? 0;

    ref.listen<AsyncValue<List<MessageEntity>>>(
      messagesProvider(widget.args.conversationId),
      (prev, next) {
        final prevLen = prev?.valueOrNull?.length ?? 0;
        final nextLen = next.valueOrNull?.length ?? 0;
        if (nextLen > prevLen && _showScrollBtn) {
          setState(() => _hasNewMsg = true);
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _GroupChatAppBar(
            groupName: groupName,
            membersCount: membersCount,
            groupAvatar: group?.avatarUrl,
            onBack: () => context.pop(),
            onInfoTap: () => context.push(
              AppRoutes.groupInfo,
              extra: widget.args.conversationId,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const ChatBackground(),
                messagesAsync.when(
                  loading: () => const MessageShimmer(),
                  error: (_, __) => Center(
                    child: Text(
                      AppStrings.somethingWrong,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  data: (messages) => messages.isEmpty
                      ? EmptyChatPlaceholder()
                      : MessageList(
                          messages: messages,
                          currentUserId: currentUserId,
                          scrollController: _scrollController,
                          isTyping: isTyping,
                          showSenderName: true,
                          onReply: (msg) => setState(() => _replyTo = msg),
                          onDelete: (msg) => ref
                              .read(
                                  messagesProvider(widget.args.conversationId)
                                      .notifier)
                              .deleteMessage(msg.id),
                          getSenderColor: (id) => _colorForSender(id),
                        ),
                ),
                if (_showScrollBtn)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ScrollToBottomButton(
                        hasNewMessage: _hasNewMsg,
                        onTap: _scrollToBottom,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          MessageInput(
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            onSendText: (text) {
              ref
                  .read(messagesProvider(widget.args.conversationId).notifier)
                  .sendText(text, replyToId: _replyTo?.id);
              setState(() => _replyTo = null);
              if (_showScrollBtn) _scrollToBottom();
            },
            onSendImage: (path, _) => ref
                .read(messagesProvider(widget.args.conversationId).notifier)
                .sendMedia(path, MessageType.image),
            onTypingChanged: (isTyping) => ref
                .read(messagesProvider(widget.args.conversationId).notifier)
                .sendTyping(isTyping),
          ),
        ],
      ),
    );
  }
}

// ── Group App Bar ──────────────────────────────────────────────────────────

class _GroupChatAppBar extends StatelessWidget {
  const _GroupChatAppBar({
    required this.groupName,
    required this.membersCount,
    required this.onBack,
    required this.onInfoTap,
    this.groupAvatar,
  });

  final String groupName;
  final int membersCount;
  final String? groupAvatar;
  final VoidCallback onBack;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            // Back
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(10),
                child: const SizedBox(
                  width: 44,
                  height: 60,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 22,
                    color: AppColors.grey700,
                  ),
                ),
              ),
            ),
            // Avatar + name (tappable → group info)
            Expanded(
              child: GestureDetector(
                onTap: onInfoTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: groupAvatar,
                      name: groupName,
                      radius: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$membersCount أعضاء',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.grey500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onInfoTap,
                borderRadius: BorderRadius.circular(10),
                child: const SizedBox(
                  width: 44,
                  height: 60,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: AppColors.grey700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
