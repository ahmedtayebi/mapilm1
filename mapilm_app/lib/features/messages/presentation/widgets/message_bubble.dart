import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/message_entity.dart';

// ── Public API ─────────────────────────────────────────────────────────────

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isFromMe,
    required this.showSenderName,
    required this.onReply,
    required this.onDelete,
    this.senderColor,
    this.isFirst = false,
  });

  final MessageEntity message;
  final bool isFromMe;
  final bool showSenderName;
  final void Function(MessageEntity) onReply;
  final void Function(MessageEntity) onDelete;
  final Color? senderColor;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _DeletedBubble(isFromMe: isFromMe);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: isFromMe
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: GestureDetector(
            onLongPress: () {
              HapticFeedback.selectionClick();
              _showOptions(context);
            },
            child: Column(
              crossAxisAlignment: isFromMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSenderName && !isFromMe && message.senderName != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      bottom: 4,
                    ),
                    child: Text(
                      message.senderName!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: senderColor ?? AppColors.primary,
                      ),
                    ),
                  ),
                if (message.replyTo != null) ...[
                  _ReplyPreview(reply: message.replyTo!, isFromMe: isFromMe),
                  const SizedBox(height: 3),
                ],
                _BubbleBody(
                  message: message,
                  isFromMe: isFromMe,
                  isFirst: isFirst,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms)
        .slideX(
          begin: isFromMe ? 0.06 : -0.06,
          end: 0,
          duration: 240.ms,
          curve: Curves.easeOutCubic,
        );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (_) => _MessageOptionsSheet(
        message: message,
        isFromMe: isFromMe,
        onReply: () {
          Navigator.pop(context);
          onReply(message);
        },
        onCopy: () {
          Navigator.pop(context);
          Clipboard.setData(ClipboardData(text: message.content ?? ''));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                AppStrings.copiedToClipboard,
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onDelete: isFromMe
            ? () {
                Navigator.pop(context);
                onDelete(message);
              }
            : null,
      ),
    );
  }
}

// ── Date Separator ─────────────────────────────────────────────────────────

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: _Hairline()),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _Hairline()),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return AppStrings.today;
    if (diff.inDays == 1) return AppStrings.yesterday;
    return DateFormat('EEEE، d MMMM', 'ar').format(dt);
  }
}

class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.glassBorder,
            AppColors.glassBorder.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

// ── Typing Indicator ───────────────────────────────────────────────────────

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(22),
            ),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => _TypingDot(controller: _ctrl, index: i),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.controller, required this.index});
  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value - index * 0.18).clamp(0.0, 1.0);
        final y = -math.sin(t * math.pi) * 4;
        final colors = AppColors.auroraStops;
        return Transform.translate(
          offset: Offset(0, y),
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2.4),
            decoration: BoxDecoration(
              color: colors[index % colors.length],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ── Bubble Body ────────────────────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.message,
    required this.isFromMe,
    required this.isFirst,
  });

  final MessageEntity message;
  final bool isFromMe;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final isImage = message.type == MessageType.image;
    return Container(
      padding: isImage
          ? const EdgeInsets.all(4)
          : const EdgeInsets.fromLTRB(15, 11, 15, 9),
      decoration: BoxDecoration(
        gradient: isFromMe
            ? const LinearGradient(
                colors: AppColors.auroraStops,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
        color: isFromMe ? null : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: isFromMe
              ? const Radius.circular(22)
              : const Radius.circular(6),
          bottomRight: isFromMe
              ? const Radius.circular(6)
              : const Radius.circular(22),
        ),
        border: isFromMe
            ? null
            : Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isFromMe
                ? AppColors.primary.withOpacity(0.32)
                : AppColors.ink.withOpacity(0.05),
            blurRadius: isFromMe ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContent(context),
          if (!isImage) ...[
            const SizedBox(height: 4),
            _buildMeta(),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: isFromMe ? Colors.white : AppColors.ink,
          ),
        );

      case MessageType.image:
        return Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl ?? '',
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 220,
                  height: 220,
                  color: AppColors.pearlDeep,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 220,
                  height: 220,
                  color: AppColors.pearlDeep,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    size: 40,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 10,
              child: _buildImageMeta(),
            ),
          ],
        );

      case MessageType.voice:
        return VoiceBubble(
          duration: message.mediaDuration ?? 0,
          isFromMe: isFromMe,
          mediaUrl: message.mediaUrl,
        );

      case MessageType.deleted:
        return Text(
          AppStrings.messageDeleted,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: isFromMe ? Colors.white60 : AppColors.inkMuted,
          ),
        );

      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              color: isFromMe ? Colors.white70 : AppColors.inkMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content ?? 'ملف',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isFromMe ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildMeta() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Text(
            'معدّل · ',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isFromMe ? Colors.white54 : AppColors.inkMuted,
            ),
          ),
        Text(
          DateFormat('HH:mm').format(message.sentAt),
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isFromMe ? Colors.white70 : AppColors.inkMuted,
            letterSpacing: 0.3,
          ),
        ),
        if (isFromMe) ...[
          const SizedBox(width: 4),
          _StatusIcon(status: message.status),
        ],
      ],
    );
  }

  Widget _buildImageMeta() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ink.withOpacity(0.55),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(message.sentAt),
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 4),
            _StatusIcon(status: message.status, onDark: true),
          ],
        ],
      ),
    );
  }
}

// ── Reply Preview ──────────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.reply, required this.isFromMe});
  final MessageEntity reply;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withOpacity(0.18)
            : AppColors.primary.withOpacity(0.06),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: BorderDirectional(
          end: BorderSide(
            color: isFromMe ? Colors.white70 : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply.senderName != null)
            Text(
              reply.senderName!,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isFromMe ? Colors.white : AppColors.primary,
                letterSpacing: 0.2,
              ),
            ),
          const SizedBox(height: 1),
          Text(
            reply.content ?? '...',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isFromMe ? Colors.white70 : AppColors.inkSoft,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Deleted Bubble ─────────────────────────────────────────────────────────

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({required this.isFromMe});
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isFromMe
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.pearlDeep.withOpacity(0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 14,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.messageDeleted,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Icon ────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, this.onDark = false});
  final MessageStatus status;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation(
              onDark ? Colors.white70 : Colors.white60,
            ),
          ),
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check_rounded,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.seen:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Color(0xFFB8FFE9),
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Color(0xFFFFB4B4),
        );
    }
  }
}

// ── Voice Bubble ───────────────────────────────────────────────────────────

class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.duration,
    required this.isFromMe,
    this.mediaUrl,
  });

  final int duration;
  final bool isFromMe;
  final String? mediaUrl;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _waveCtrl.repeat(reverse: true);
    } else {
      _waveCtrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isFromMe ? Colors.white : AppColors.inkSoft;
    final accent =
        widget.isFromMe ? Colors.white : AppColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.isFromMe
                  ? Colors.white.withOpacity(0.2)
                  : AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isFromMe
                    ? Colors.white.withOpacity(0.4)
                    : AppColors.primary.withOpacity(0.25),
              ),
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isFromMe ? Colors.white : AppColors.primary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) {
                return Row(
                  children: List.generate(22, (i) {
                    final baseH = 4.0 + (i % 5) * 4.5;
                    final animH = _isPlaying
                        ? baseH +
                            math.sin(
                                  (_waveCtrl.value + i * 0.3) * math.pi,
                                ) *
                                6
                        : baseH;
                    final progressed = i < (_isPlaying ? 11 : 0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 2.5,
                      height: animH.clamp(4.0, 22.0),
                      decoration: BoxDecoration(
                        color: progressed
                            ? accent
                            : fg.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 5),
            Text(
              _formatDuration(widget.duration),
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: fg.withOpacity(0.75),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Message Options Sheet ──────────────────────────────────────────────────

class _MessageOptionsSheet extends StatelessWidget {
  const _MessageOptionsSheet({
    required this.message,
    required this.isFromMe,
    required this.onReply,
    required this.onCopy,
    this.onDelete,
  });

  final MessageEntity message;
  final bool isFromMe;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      decoration: BoxDecoration(
        color: AppColors.pearl,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          _OptionTile(
            icon: Icons.reply_rounded,
            label: AppStrings.reply,
            color: AppColors.primary,
            onTap: onReply,
          ),
          if (message.type == MessageType.text)
            _OptionTile(
              icon: Icons.copy_rounded,
              label: AppStrings.copy,
              color: AppColors.violet,
              onTap: onCopy,
            ),
          if (onDelete != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Divider(height: 1, color: AppColors.glassBorder),
            ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: AppStrings.deleteMessage,
              color: AppColors.error,
              onTap: onDelete!,
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: color == AppColors.error ? AppColors.error : AppColors.ink,
        ),
      ),
    );
  }
}
