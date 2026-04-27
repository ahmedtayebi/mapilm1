import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../providers/profile_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        title: const Text(
          'المحادثات المحظورة',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.grey900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.grey700),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: contactsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 38,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'حدث خطأ',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(contactsProvider),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                ),
                child: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
            ],
          ),
        ),
        data: (contacts) {
          final blocked = contacts.where((c) => c.isBlocked).toList();

          if (blocked.isEmpty) {
            return _BlockedEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: blocked.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final contact = blocked[i];
              return _BlockedTile(
                id: contact.id,
                name: contact.displayName,
                phone: contact.phone,
                avatarUrl: contact.avatarUrl,
                onUnblock: () async {
                  final ok = await ConfirmationDialog.show(
                    context,
                    title: 'إلغاء الحظر',
                    message:
                        'هل تريد إلغاء حظر ${contact.displayName}؟\nستتمكن من التواصل معه مجدداً.',
                    confirmLabel: 'إلغاء الحظر',
                    isDestructive: false,
                    icon: Icons.lock_open_rounded,
                  );
                  if (ok) {
                    ref.read(contactsProvider.notifier).unblockUser(contact.id);
                  }
                },
              ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.08);
            },
          );
        },
      ),
    );
  }
}

// ── Blocked Tile ───────────────────────────────────────────────────────────

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl,
    required this.onUnblock,
  });
  final String id;
  final String name;
  final String phone;
  final String? avatarUrl;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            // Avatar with blocked indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(imageUrl: avatarUrl, name: name, radius: 26),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.grey500,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Unblock button
            OutlinedButton(
              onPressed: onUnblock,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'إلغاء الحظر',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _BlockedEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 48,
                color: AppColors.grey400,
              ),
            )
                .animate()
                .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                    duration: 400.ms)
                .fadeIn(),
            const SizedBox(height: 24),
            Text(
              'لا يوجد مستخدمون محظورون',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.grey800,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 10),
            Text(
              'المستخدمون الذين تحظرهم سيظهرون هنا ولن يتمكنوا من التواصل معك',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.grey500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 160.ms),
          ],
        ),
      ),
    );
  }
}
