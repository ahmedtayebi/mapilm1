import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/presence_orb.dart';
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
      backgroundColor: AppColors.pearl,
      body: Column(
        children: [
          _ChatAppBar(args: widget.args, isTyping: isTyping),
          Expanded(
            child: Stack(
              children: [
                const ChatBackground(),
                messagesAsync.when(
                  loading: () => const MessageShimmer(),
                  error: (_, __) => Center(
                    child: Text(
                      AppStrings.somethingWrong,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  data: (messages) => messages.isEmpty
                      ? const EmptyChatPlaceholder()
                      : MessageList(
                          messages: messages,
                          currentUserId: currentUserId,
                          scrollController: _scrollController,
                          isTyping: isTyping,
                          showSenderName: false,
                          onReply: (msg) =>
                              setState(() => _replyTo = msg),
                          onDelete: (msg) => ref
                              .read(messagesProvider(
                                      widget.args.conversationId)
                                  .notifier)
                              .deleteMessage(msg.id),
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

// ── Chat App Bar ───────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({required this.args, required this.isTyping});
  final ChatScreenArgs args;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: topPad),
          decoration: BoxDecoration(
            color: AppColors.pearl.withOpacity(0.78),
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder.withOpacity(0.6),
              ),
            ),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
              child: Row(
                children: [
                  _BarIcon(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  PresenceOrb(
                    imageUrl: args.participantAvatar,
                    name: args.participantName,
                    radius: 20,
                    isOnline: !isTyping,
                    ringWidth: 2,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.participantName,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: isTyping
                              ? const _TypingStatus(key: ValueKey('typing'))
                              : Text(
                                  key: const ValueKey('online'),
                                  AppStrings.online,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.online,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  _BarIcon(
                    icon: Icons.videocam_outlined,
                    onTap: () {},
                  ),
                  const SizedBox(width: 6),
                  _BarIcon(
                    icon: Icons.more_horiz_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, size: 18, color: AppColors.inkSoft),
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
        const Text(
          AppStrings.typing,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
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
          final colors = AppColors.auroraStops;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.2),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colors[i % colors.length].withOpacity(opacity),
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

/// Public — also used by group_chat_screen.
class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.pearl, Color(0xFFEDEAE0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Aurora bloom upper-end.
            const PositionedDirectional(
              top: 40,
              end: -120,
              child: _Bloom(
                size: 280,
                colors: [
                  Color(0x442038F5),
                  Color(0x117C5CFF),
                  Color(0x00000000),
                ],
              ),
            ),
            // Warm bloom lower-start.
            const PositionedDirectional(
              bottom: 80,
              start: -140,
              child: _Bloom(
                size: 300,
                colors: [
                  Color(0x33FF6B9B),
                  Color(0x22FF8A65),
                  Color(0x00000000),
                ],
              ),
            ),
            // Faint grid lines for depth.
            const Positioned.fill(child: _GridLines()),
          ],
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.colors});
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors, stops: const [0, 0.55, 1]),
      ),
    );
  }
}

class _GridLines extends StatelessWidget {
  const _GridLines();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withOpacity(0.025)
      ..strokeWidth = 0.6;
    const spacing = 32.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Message List ───────────────────────────────────────────────────────────

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
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
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (isTyping && i == 0) {
          return const TypingIndicator()
              .animate()
              .fadeIn(duration: 200.ms)
              .slideX(begin: -0.05);
        }
        final msgIndex = isTyping ? i - 1 : i;
        final msg = messages[msgIndex];
        final isFromMe = msg.isFromMe(currentUserId);

        final showDate = msgIndex == messages.length - 1 ||
            !_isSameDay(msg.sentAt, messages[msgIndex + 1].sentAt);

        return Column(
          children: [
            if (showDate) DateSeparator(date: msg.sentAt),
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

// ── Empty Placeholder ──────────────────────────────────────────────────────

class EmptyChatPlaceholder extends StatelessWidget {
  const EmptyChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.violet.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 36,
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
          const Text(
            'الفضاء مفتوح. أرسل أول رسالة.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

// ── Scroll-to-Bottom Pill ──────────────────────────────────────────────────

class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({
    super.key,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNewMessage) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.auroraStops,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'رسالة جديدة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.inkSoft,
              size: 20,
            ),
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
