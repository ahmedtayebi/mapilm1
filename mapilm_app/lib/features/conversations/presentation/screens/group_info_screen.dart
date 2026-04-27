import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../providers/conversations_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: conversationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Text(
            AppStrings.somethingWrong,
            style: AppTypography.bodyMedium,
          ),
        ),
        data: (conversations) {
          final group = conversations.firstWhere(
            (c) => c.id == groupId,
            orElse: () => conversations.first,
          );
          final isAdmin = group.participants.isNotEmpty &&
              group.participants.first.id == currentUserId;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Collapsible header
              SliverAppBar(
                expandedHeight: 240,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.grey700),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _GroupHeader(
                    group: group,
                    isAdmin: isAdmin,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.divider),
                ),
              ),

              // Action buttons row
              SliverToBoxAdapter(
                child: _ActionButtons(
                  onMute: () {},
                  onLeave: () => _confirmLeave(context),
                ),
              ),

              // Members section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        AppStrings.participants,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${group.participants.length}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add member tile (admin only)
              if (isAdmin)
                SliverToBoxAdapter(
                  child: _AddMemberTile(onTap: () {}),
                ),

              // Members list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MemberTile(
                    member: group.participants[i],
                    isAdmin: i == 0,
                    isCurrentUser:
                        group.participants[i].id == currentUserId,
                    canManage: isAdmin,
                    onTap: isAdmin && group.participants[i].id != currentUserId
                        ? () => _showMemberOptions(
                              context,
                              group.participants[i],
                            )
                        : null,
                  ).animate().fadeIn(delay: Duration(milliseconds: i * 40)),
                  childCount: group.participants.length,
                ),
              ),

              // Danger zone
              SliverToBoxAdapter(
                child: _DangerZone(
                  isAdmin: isAdmin,
                  onLeave: () => _confirmLeave(context),
                  onDelete: isAdmin ? () => _confirmDelete(context) : null,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStrings.leaveGroup, textAlign: TextAlign.right),
        content: const Text(
          'هل تريد مغادرة هذه المجموعة؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AppStrings.leaveGroup),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المجموعة', textAlign: TextAlign.right),
        content: const Text(
          'سيتم حذف المجموعة نهائياً لجميع الأعضاء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showMemberOptions(BuildContext context, UserEntity member) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: member.avatarUrl,
                    name: member.name,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    member.name ?? member.phone,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.primary, size: 20),
              ),
              title: Text(
                AppStrings.makeAdmin,
                style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_remove_rounded,
                    color: AppColors.error, size: 20),
              ),
              title: Text(
                AppStrings.removeMember,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Group Header ───────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.isAdmin});
  final dynamic group;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        bottom: 16,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              AppAvatar(
                imageUrl: group.avatarUrl,
                name: group.name,
                radius: 50,
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                    duration: 500.ms,
                  )
                  .fadeIn(),
              if (isAdmin)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            group.name ?? '',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 4),
          Text(
            '${group.participants.length} أعضاء',
            style: AppTypography.bodySmall.copyWith(color: AppColors.grey500),
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }
}

// ── Action Buttons ─────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onMute, required this.onLeave});
  final VoidCallback onMute;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionBtn(
            icon: Icons.volume_off_rounded,
            label: 'كتم الصوت',
            color: AppColors.grey600,
            onTap: onMute,
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.exit_to_app_rounded,
            label: 'المغادرة',
            color: AppColors.error,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Member Tile ────────────────────────────────────────────────────────

class _AddMemberTile extends StatelessWidget {
  const _AddMemberTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                AppStrings.addMember,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Member Tile ────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isAdmin,
    required this.isCurrentUser,
    required this.canManage,
    this.onTap,
  });

  final UserEntity member;
  final bool isAdmin;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: member.avatarUrl,
                name: member.name,
                radius: 23,
                showOnlineIndicator: true,
                isOnline: member.isOnline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isCurrentUser
                                ? '${member.name ?? member.phone} (أنت)'
                                : member.name ?? member.phone,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLighter,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 11,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  AppStrings.admin,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (member.bio != null && member.bio!.isNotEmpty)
                      Text(
                        member.bio!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.grey500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.grey400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Danger Zone ────────────────────────────────────────────────────────────

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.isAdmin,
    required this.onLeave,
    this.onDelete,
  });
  final bool isAdmin;
  final VoidCallback onLeave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorLight, width: 1),
      ),
      child: Column(
        children: [
          _DangerOption(
            icon: Icons.exit_to_app_rounded,
            label: AppStrings.leaveGroup,
            onTap: onLeave,
          ),
          if (isAdmin && onDelete != null) ...[
            const Divider(height: 1, color: AppColors.errorLight),
            _DangerOption(
              icon: Icons.delete_forever_rounded,
              label: 'حذف المجموعة',
              onTap: onDelete!,
            ),
          ],
        ],
      ),
    );
  }
}

class _DangerOption extends StatelessWidget {
  const _DangerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.error, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
