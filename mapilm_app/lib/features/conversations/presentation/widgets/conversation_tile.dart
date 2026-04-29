import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/presence_orb.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../messages/presentation/screens/group_chat_screen.dart';

export '../../../messages/presentation/screens/chat_screen.dart' show ChatScreenArgs;
export '../../../messages/presentation/screens/group_chat_screen.dart' show GroupChatScreenArgs;

/// Glass-card conversation tile (Mapilm aurora redesign).
///
/// Replaces the legacy list row with a rounded card that floats on the pearl
/// canvas. Uses [PresenceOrb] in place of a flat avatar; meta row shows
/// last-message time + unread count as a gradient pill.
class ConversationTile extends ConsumerStatefulWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    this.onArchive,
    this.onDelete,
  });

  final ConversationEntity conversation;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  ConsumerState<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends ConsumerState<ConversationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.uid ?? '';
    final conv = widget.conversation;
    final name = conv.displayName(currentUserId);
    final avatar = conv.displayAvatar(currentUserId);
    final isOnline = !conv.isGroup &&
        conv.participants.any((p) => p.id != currentUserId && p.isOnline);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Dismissible(
        key: ValueKey(conv.id),
        direction: DismissDirection.horizontal,
        confirmDismiss: (dir) async {
          HapticFeedback.mediumImpact();
          if (dir == DismissDirection.startToEnd) {
            widget.onArchive?.call();
            return false;
          } else {
            return await _confirmDelete(context);
          }
        },
        onDismissed: (_) => widget.onDelete?.call(),
        background: _swipeBg(
          colors: const [Color(0xFF22D3B3), Color(0xFF1FA48F)],
          icon: Icons.archive_outlined,
          label: 'أرشفة',
          alignment: AlignmentDirectional.centerStart,
        ),
        secondaryBackground: _swipeBg(
          colors: const [Color(0xFFFF6B9B), Color(0xFFE53935)],
          icon: Icons.delete_outline_rounded,
          label: 'حذف',
          alignment: AlignmentDirectional.centerEnd,
        ),
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            _navigate(context, conv, currentUserId, name, avatar);
          },
          onTapCancel: () => _pressCtrl.reverse(),
          onLongPress: () {
            HapticFeedback.selectionClick();
            _showContextMenu(context);
          },
          child: AnimatedBuilder(
            animation: _pressAnim,
            builder: (_, child) =>
                Transform.scale(scale: _pressAnim.value, child: child),
            child: _Card(
              conv: conv,
              name: name,
              avatar: avatar,
              isOnline: isOnline,
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, ConversationEntity conv,
      String currentUserId, String name, String? avatar) {
    if (conv.isGroup) {
      context.push(AppRoutes.groupChat,
          extra: GroupChatScreenArgs(conversationId: conv.id));
    } else {
      context.push(
        AppRoutes.chat,
        extra: ChatScreenArgs(
          conversationId: conv.id,
          participantName: name,
          participantAvatar: avatar,
          participantId: conv.participants
              .firstWhere(
                (p) => p.id != currentUserId,
                orElse: () => conv.participants.first,
              )
              .id,
        ),
      );
    }
  }

  Widget _swipeBg({
    required List<Color> colors,
    required IconData icon,
    required String label,
    required AlignmentGeometry alignment,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        alignment: alignment,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      // Render above MainShell's floating dock.
      useRootNavigator: true,
      builder: (_) => _ContextMenu(
        onArchive: widget.onArchive,
        onDelete: () async {
          final confirmed = await _confirmDelete(context);
          if (confirmed) widget.onDelete?.call();
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('حذف المحادثة', textAlign: TextAlign.right),
            content: const Text(
              'هل تريد حذف هذه المحادثة نهائياً؟',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ── Card body ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.conv,
    required this.name,
    required this.avatar,
    required this.isOnline,
  });

  final ConversationEntity conv;
  final String name;
  final String? avatar;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.hasUnread;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: hasUnread ? Colors.white : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasUnread
              ? AppColors.primary.withOpacity(0.18)
              : AppColors.glassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(hasUnread ? 0.07 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PresenceOrb(
                imageUrl: avatar,
                name: name,
                radius: 26,
                isOnline: isOnline,
                colors: conv.isGroup
                    ? const [
                        AppColors.violet,
                        AppColors.peach,
                        AppColors.mint,
                      ]
                    : null,
              ),
              if (conv.isGroup)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.violet, AppColors.primary],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.pearl,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.diversity_3_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(child: _Body(conv: conv, name: name, hasUnread: hasUnread)),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.conv,
    required this.name,
    required this.hasUnread,
  });

  final ConversationEntity conv;
  final String name;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15.5,
                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conv.lastMessageAt != null)
              Text(
                _formatTime(conv.lastMessageAt!),
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                  color: hasUnread ? AppColors.primary : AppColors.inkMuted,
                  letterSpacing: 0.2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                conv.lastMessage ?? 'ابدأ المحادثة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  height: 1.35,
                  color:
                      hasUnread ? AppColors.inkSoft : AppColors.inkMuted,
                  fontWeight:
                      hasUnread ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 10),
              _UnreadPill(count: conv.unreadCount),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) {
      const days = [
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      return days[dt.weekday - 1];
    }
    return DateFormat('dd/MM').format(dt);
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.auroraStops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.32),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontFamily: 'Tajawal',
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Context menu sheet ────────────────────────────────────────────────────

class _ContextMenu extends StatelessWidget {
  const _ContextMenu({this.onArchive, this.onDelete});
  final VoidCallback? onArchive;
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
          _ContextOption(
            icon: Icons.archive_outlined,
            label: 'أرشفة المحادثة',
            color: AppColors.mint,
            onTap: () {
              Navigator.pop(context);
              onArchive?.call();
            },
          ),
          _ContextOption(
            icon: Icons.notifications_off_outlined,
            label: 'كتم الإشعارات',
            color: AppColors.violet,
            onTap: () => Navigator.pop(context),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Divider(height: 1, color: AppColors.glassBorder),
          ),
          _ContextOption(
            icon: Icons.delete_outline_rounded,
            label: 'حذف المحادثة',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              onDelete?.call();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ContextOption extends StatelessWidget {
  const _ContextOption({
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
