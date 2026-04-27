import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
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
      padding: const EdgeInsets.only(bottom: 3),
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
                      start: 12,
                      bottom: 3,
                    ),
                    child: Text(
                      message.senderName!,
                      style: AppTypography.labelSmall.copyWith(
                        color: senderColor ?? AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (message.replyTo != null) ...[
                  _ReplyPreview(reply: message.replyTo!, isFromMe: isFromMe),
                  const SizedBox(height: 2),
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
        .fadeIn(duration: 200.ms)
        .slideX(
          begin: isFromMe ? 0.08 : -0.08,
          end: 0,
          duration: 220.ms,
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
              content: const Text(AppStrings.copiedToClipboard),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.divider,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _formatDate(date),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.grey500,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: AppColors.divider),
          ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => _TypingDot(
              controller: _ctrl,
              delay: i * 0.2,
            )),
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.controller, required this.delay});
  final AnimationController controller;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value - delay).clamp(0.0, 1.0);
        final y = -math.sin(t * math.pi) * 4;
        return Transform.translate(
          offset: Offset(0, y),
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.grey400,
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
          ? const EdgeInsets.all(3)
          : const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        gradient: isFromMe
            ? const LinearGradient(
                colors: [Color(0xFF2038F5), Color(0xFF4B6EF5)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
        color: isFromMe ? null : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isFromMe
              ? const Radius.circular(20)
              : const Radius.circular(4),
          bottomRight: isFromMe
              ? const Radius.circular(4)
              : const Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isFromMe
                ? AppColors.primary.withOpacity(0.25)
                : Colors.black.withOpacity(0.06),
            blurRadius: isFromMe ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContent(context),
          if (!isImage) ...[
            const SizedBox(height: 3),
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
          style: AppTypography.messageText.copyWith(
            color: isFromMe ? Colors.white : AppColors.onBubbleIncoming,
          ),
        );

      case MessageType.image:
        return Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl ?? '',
                width: 220,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 220,
                  height: 200,
                  color: AppColors.grey200,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 220,
                  height: 200,
                  color: AppColors.grey100,
                  child: const Icon(Icons.broken_image_rounded,
                      size: 40, color: AppColors.grey300),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 8,
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
          style: AppTypography.bodySmall.copyWith(
            fontStyle: FontStyle.italic,
            color: isFromMe ? Colors.white60 : AppColors.grey500,
          ),
        );

      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: isFromMe ? Colors.white70 : AppColors.grey500,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content ?? 'ملف',
                style: AppTypography.bodyMedium.copyWith(
                  color: isFromMe ? Colors.white : AppColors.onSurface,
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
            style: AppTypography.messageTime.copyWith(
              color: isFromMe ? Colors.white54 : AppColors.grey400,
              fontSize: 10,
            ),
          ),
        Text(
          DateFormat('HH:mm').format(message.sentAt),
          style: AppTypography.messageTime.copyWith(
            color: isFromMe ? Colors.white70 : AppColors.grey400,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(message.sentAt),
            style: AppTypography.messageTime.copyWith(
              color: Colors.white,
              fontSize: 10,
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withOpacity(0.18)
            : AppColors.primaryLighter,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border(
          right: BorderSide(
            color: isFromMe ? Colors.white70 : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reply.senderName != null)
                  Text(
                    reply.senderName!,
                    style: AppTypography.labelSmall.copyWith(
                      color: isFromMe ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  reply.content ?? '...',
                  style: AppTypography.bodySmall.copyWith(
                    color: isFromMe ? Colors.white70 : AppColors.grey600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isFromMe
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 14,
                color: AppColors.grey400,
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.messageDeleted,
                style: AppTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.grey500,
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
        return Icon(
          Icons.check_rounded,
          size: 14,
          color: onDark ? Colors.white70 : Colors.white70,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: onDark ? Colors.white70 : Colors.white70,
        );
      case MessageStatus.seen:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: onDark ? Colors.lightBlueAccent : Colors.lightBlueAccent,
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Colors.redAccent,
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
    final fgColor = widget.isFromMe ? Colors.white : AppColors.grey600;
    final accentColor =
        widget.isFromMe ? Colors.white70 : AppColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isFromMe ? Colors.white : AppColors.primary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Waveform + duration
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) {
                return Row(
                  children: List.generate(20, (i) {
                    final baseH = 4.0 + (i % 5) * 5.0;
                    final animH = _isPlaying
                        ? baseH +
                            math.sin(
                                  (_waveCtrl.value + i * 0.3) * math.pi,
                                ) *
                                6
                        : baseH;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 3,
                      height: animH.clamp(4.0, 24.0),
                      decoration: BoxDecoration(
                        color: i < (_isPlaying ? 10 : 0)
                            ? accentColor
                            : fgColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              _formatDuration(widget.duration),
              style: AppTypography.messageTime.copyWith(
                color: fgColor.withOpacity(0.7),
                fontSize: 11,
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
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
              color: AppColors.grey600,
              onTap: onCopy,
            ),
          if (onDelete != null) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: AppStrings.deleteMessage,
              color: AppColors.error,
              onTap: onDelete!,
            ),
          ],
          const SizedBox(height: 8),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: color == AppColors.error ? AppColors.error : AppColors.grey800,
        ),
      ),
    );
  }
}
