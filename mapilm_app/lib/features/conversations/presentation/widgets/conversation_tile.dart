import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../messages/presentation/screens/group_chat_screen.dart';

export '../../../messages/presentation/screens/chat_screen.dart' show ChatScreenArgs;
export '../../../messages/presentation/screens/group_chat_screen.dart' show GroupChatScreenArgs;

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
      duration: const Duration(milliseconds: 80),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
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

    return Dismissible(
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
      background: _buildSwipeBackground(
        color: AppColors.primary,
        icon: Icons.archive_rounded,
        label: 'أرشفة',
        alignment: AlignmentDirectional.centerStart,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: AppColors.error,
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
          builder: (context, child) => Transform.scale(
            scale: _pressAnim.value,
            child: child,
          ),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
            child: Row(
              children: [
                _buildAvatar(conv, currentUserId),
                const SizedBox(width: 12),
                Expanded(child: _buildContent(conv, name)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ConversationEntity conv, String currentUserId) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppAvatar(
          imageUrl: conv.displayAvatar(currentUserId),
          name: conv.displayName(currentUserId),
          radius: 27,
          showOnlineIndicator: !conv.isGroup,
          isOnline: conv.participants.any((p) => p.id != currentUserId && p.isOnline),
        ),
        if (conv.isGroup)
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.group_rounded, size: 11, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(ConversationEntity conv, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: AppTypography.conversationTitle.copyWith(
                  fontWeight: conv.hasUnread ? FontWeight.w700 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conv.lastMessageAt != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatTime(conv.lastMessageAt!),
                style: AppTypography.labelSmall.copyWith(
                  color: conv.hasUnread ? AppColors.primary : AppColors.grey400,
                  fontWeight: conv.hasUnread ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                conv.lastMessage ?? '',
                style: AppTypography.conversationPreview.copyWith(
                  color: conv.hasUnread ? AppColors.grey700 : AppColors.grey500,
                  fontWeight: conv.hasUnread ? FontWeight.w500 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conv.hasUnread) ...[
              const SizedBox(width: 8),
              _UnreadBadge(count: conv.unreadCount),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required AlignmentGeometry alignment,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.85)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              .firstWhere((p) => p.id != currentUserId,
                  orElse: () => conv.participants.first)
              .id,
        ),
      );
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => _ConversationContextMenu(
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
              borderRadius: BorderRadius.circular(20),
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) {
      const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return days[dt.weekday - 1];
    }
    return DateFormat('dd/MM').format(dt);
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.unreadBadge.copyWith(fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ConversationContextMenu extends StatelessWidget {
  const _ConversationContextMenu({this.onArchive, this.onDelete});
  final VoidCallback? onArchive;
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
          _ContextOption(
            icon: Icons.archive_rounded,
            label: 'أرشفة المحادثة',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              onArchive?.call();
            },
          ),
          _ContextOption(
            icon: Icons.volume_off_rounded,
            label: 'كتم الإشعارات',
            color: AppColors.grey600,
            onTap: () => Navigator.pop(context),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _ContextOption(
            icon: Icons.delete_outline_rounded,
            label: 'حذف المحادثة',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              onDelete?.call();
            },
          ),
          const SizedBox(height: 8),
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
