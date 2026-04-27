import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/messages_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

// ── Args ───────────────────────────────────────────────────────────────────

class ChatScreenArgs {
  const ChatScreenArgs({
    required this.conversationId,
    required this.participantName,
    this.participantAvatar,
    this.participantId,
  });
  final String conversationId;
  final String participantName;
  final String? participantAvatar;
  final String? participantId;
}

// ── Screen ─────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.args});
  final ChatScreenArgs args;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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
    // Load more when near end (list is reversed, so end = older messages)
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

    // Listen for new messages to show scroll button
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
          // Premium App Bar
          _ChatAppBar(args: widget.args, isTyping: isTyping),
          // Chat content with background
          Expanded(
            child: Stack(
              children: [
                // Background
                const ChatBackground(),
                // Messages
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
                          showSenderName: false,
                          onReply: (msg) => setState(() => _replyTo = msg),
                          onDelete: (msg) => ref
                              .read(messagesProvider(widget.args.conversationId)
                                  .notifier)
                              .deleteMessage(msg.id),
                        ),
                ),
                // Scroll to bottom button
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
          // Input area
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

// ── Chat App Bar ───────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({required this.args, required this.isTyping});
  final ChatScreenArgs args;
  final bool isTyping;

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
            // Back button
            _BarBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.pop(),
            ),
            // Avatar + name
            AppAvatar(
              imageUrl: args.participantAvatar,
              name: args.participantName,
              radius: 21,
              showOnlineIndicator: true,
              isOnline: !isTyping,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    args.participantName,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isTyping
                        ? _TypingStatus(key: const ValueKey('typing'))
                        : Text(
                            key: const ValueKey('online'),
                            AppStrings.online,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.online,
                              fontSize: 11,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // Action buttons
            _BarBtn(
              icon: Icons.videocam_outlined,
              onTap: () {},
              color: AppColors.grey400,
            ),
            _BarBtn(
              icon: Icons.more_vert_rounded,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  const _BarBtn({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 60,
          child: Icon(
            icon,
            size: 22,
            color: color ?? AppColors.grey700,
          ),
        ),
      ),
    );
  }
}

class _TypingStatus extends StatelessWidget {
  const _TypingStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.typing,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.primary,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 4),
        _DotsRow(),
      ],
    );
  }
}

class _DotsRow extends StatefulWidget {
  @override
  State<_DotsRow> createState() => _DotsRowState();
}

class _DotsRowState extends State<_DotsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value + i * 0.25) % 1.0;
          final opacity = math.sin(t * math.pi).clamp(0.3, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Chat Background ────────────────────────────────────────────────────────

class ChatBackground extends StatelessWidget {
  const ChatBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _DotPatternPainter(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF4F6FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2038F5).withOpacity(0.04)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => false;
}

// ── Message List ───────────────────────────────────────────────────────────

class MessageList extends StatelessWidget {
  const MessageList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.isTyping,
    required this.showSenderName,
    required this.onReply,
    required this.onDelete,
    this.getSenderColor,
  });

  final List<MessageEntity> messages;
  final String currentUserId;
  final ScrollController scrollController;
  final bool isTyping;
  final bool showSenderName;
  final void Function(MessageEntity) onReply;
  final void Function(MessageEntity) onDelete;
  final Color? Function(String senderId)? getSenderColor;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Typing indicator at top (index 0 in reversed list)
        if (isTyping && i == 0) {
          return const TypingIndicator()
              .animate()
              .fadeIn(duration: 200.ms)
              .slideX(begin: -0.05);
        }

        final msgIndex = isTyping ? i - 1 : i;
        final msg = messages[msgIndex];
        final isFromMe = msg.isFromMe(currentUserId);

        // Date separator logic
        final showDate = msgIndex == messages.length - 1 ||
            !_isSameDay(
              msg.sentAt,
              messages[msgIndex + 1].sentAt,
            );

        return Column(
          children: [
            if (showDate)
              DateSeparator(date: msg.sentAt),
            MessageBubble(
              message: msg,
              isFromMe: isFromMe,
              showSenderName: showSenderName,
              onReply: onReply,
              onDelete: onDelete,
              senderColor: getSenderColor?.call(msg.senderId),
              isFirst: msgIndex == 0,
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class EmptyChatPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 38,
              color: AppColors.primary,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(),
          const SizedBox(height: 16),
          Text(
            'ابدأ المحادثة!',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.grey400),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

// ── Scroll to Bottom Button ────────────────────────────────────────────────

class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({
    required this.hasNewMessage,
    required this.onTap,
  });
  final bool hasNewMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNewMessage) ...[
              const Text(
                'رسالة جديدة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          curve: Curves.easeOutBack,
          duration: 250.ms,
        )
        .fadeIn(duration: 200.ms);
  }
}
