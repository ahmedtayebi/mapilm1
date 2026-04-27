import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../providers/profile_provider.dart';
import 'blocked_users_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSize = '...';
  String _lastSeenPrivacy = 'الجميع';
  String _avatarPrivacy = 'الجميع';

  @override
  void initState() {
    super.initState();
    _computeCacheSize();
  }

  Future<void> _computeCacheSize() async {
    try {
      final tempDir = Directory.systemTemp;
      int totalBytes = 0;
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(recursive: true)) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }
      final mb = totalBytes / (1024 * 1024);
      if (mounted) {
        setState(() => _cacheSize = '${mb.toStringAsFixed(1)} MB');
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '0.0 MB');
    }
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = Directory.systemTemp;
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
      // Also clear image cache
      imageCache.clear();
      imageCache.clearLiveImages();
      if (mounted) {
        setState(() => _cacheSize = '0.0 MB');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم مسح ذاكرة التخزين المؤقت'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: AppStrings.logout,
      message: 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      confirmLabel: AppStrings.logout,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (ok && mounted) {
      await ref.read(meProvider.notifier).logout();
      if (mounted) context.go(AppRoutes.splash);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'حذف الحساب',
      message:
          'سيتم حذف حسابك وجميع بياناتك نهائياً ولا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف الحساب',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (ok && mounted) {
      await ref.read(meProvider.notifier).logout();
      if (mounted) context.go(AppRoutes.splash);
    }
  }

  void _showPrivacyPicker(String title, String current, ValueChanged<String> onSelect) {
    final options = ['الجميع', 'جهات الاتصال', 'لا أحد'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((opt) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(
                    opt,
                    style: const TextStyle(
                        fontFamily: 'Tajawal', fontWeight: FontWeight.w500),
                  ),
                  trailing: current == opt
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : const Icon(Icons.radio_button_unchecked_rounded,
                          color: AppColors.grey300),
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        title: const Text(
          'الإعدادات',
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
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // Profile header card
          meAsync.when(
            loading: () => _ProfileHeaderShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (user) => _ProfileCard(
              user: user,
              onTap: () => context.push(AppRoutes.profile),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06),
          ),

          const SizedBox(height: 16),

          // Section 1: Notifications
          _buildSectionCard(
            title: 'الإشعارات',
            delay: 80.ms,
            children: [
              _ToggleRow(
                icon: Icons.message_rounded,
                label: 'إشعارات الرسائل',
                value: settings.notifyMessages,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggle('messages'),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.group_rounded,
                label: 'إشعارات المجموعات',
                value: settings.notifyGroups,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggle('groups'),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.volume_up_rounded,
                label: 'الأصوات',
                value: settings.sounds,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggle('sounds'),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.vibration_rounded,
                label: 'الاهتزاز',
                value: settings.vibration,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggle('vibration'),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Section 2: Privacy
          _buildSectionCard(
            title: 'الخصوصية',
            delay: 130.ms,
            children: [
              _NavRow(
                icon: Icons.access_time_rounded,
                label: 'آخر ظهور',
                value: _lastSeenPrivacy,
                onTap: () => _showPrivacyPicker(
                  'من يرى آخر ظهور',
                  _lastSeenPrivacy,
                  (v) => setState(() => _lastSeenPrivacy = v),
                ),
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.image_rounded,
                label: 'الصورة الشخصية',
                value: _avatarPrivacy,
                onTap: () => _showPrivacyPicker(
                  'من يرى صورتك الشخصية',
                  _avatarPrivacy,
                  (v) => setState(() => _avatarPrivacy = v),
                ),
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.block_rounded,
                label: 'المحادثات المحظورة',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BlockedUsersScreen(),
                  ),
                ),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Section 3: Storage
          _buildSectionCard(
            title: 'التخزين والبيانات',
            delay: 180.ms,
            children: [
              _NavRow(
                icon: Icons.storage_rounded,
                label: 'مسح ذاكرة التخزين المؤقت',
                value: _cacheSize,
                onTap: () async {
                  final ok = await ConfirmationDialog.show(
                    context,
                    title: 'مسح ذاكرة التخزين',
                    message: 'هل تريد مسح ذاكرة التخزين المؤقت (${_cacheSize})؟',
                    confirmLabel: 'مسح',
                    icon: Icons.delete_sweep_rounded,
                  );
                  if (ok) _clearCache();
                },
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Section 4: About
          _buildSectionCard(
            title: 'حول التطبيق',
            delay: 230.ms,
            children: [
              _NavRow(
                icon: Icons.info_outline_rounded,
                label: 'الإصدار',
                value: '1.0.0',
                onTap: () {},
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.privacy_tip_outlined,
                label: 'سياسة الخصوصية',
                onTap: () => _showInfoSnackBar('سياسة الخصوصية'),
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.description_outlined,
                label: 'شروط الاستخدام',
                onTap: () => _showInfoSnackBar('شروط الاستخدام'),
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.star_outline_rounded,
                label: 'تقييم التطبيق',
                onTap: () => _showInfoSnackBar('شكراً لك على دعمك!'),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Danger zone
          _buildDangerCard(delay: 280.ms),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    required Duration delay,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              title,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.grey500,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Container(
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
            child: Column(children: children),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.06);
  }

  Widget _buildDangerCard({required Duration delay}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              'الحساب',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.grey500,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Container(
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
            child: Column(
              children: [
                _DangerRow(
                  icon: Icons.logout_rounded,
                  label: AppStrings.logout,
                  onTap: _logout,
                ),
                const _Divider(),
                _DangerRow(
                  icon: Icons.delete_forever_rounded,
                  label: 'حذف الحساب',
                  onTap: _deleteAccount,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.06);
  }

  void _showInfoSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── Profile Header Card ────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  // Avatar with glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: AppAvatar(
                      imageUrl: user['avatar_url'] as String?,
                      name: user['name'] as String?,
                      radius: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] as String? ?? '',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user['phone'] as String? ?? '',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.grey500,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                        if (user['bio'] != null &&
                            (user['bio'] as String).isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            user['bio'] as String,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.grey400,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_left_rounded,
                      color: AppColors.grey400, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Toggle Row ─────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _RowWrapper(
      isLast: isLast,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconBox(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey800,
                ),
              ),
            ),
            _AnimatedToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ── Animated Toggle ────────────────────────────────────────────────────────

class _AnimatedToggle extends StatelessWidget {
  const _AnimatedToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: value
              ? const LinearGradient(
                  colors: [Color(0xFF2038F5), Color(0xFF1429C8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [AppColors.grey200, AppColors.grey300],
                ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav Row ────────────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _RowWrapper(
      isLast: isLast,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBox(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey800,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.grey400,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded,
                size: 18, color: AppColors.grey300),
          ],
        ),
      ),
    );
  }
}

// ── Danger Row ─────────────────────────────────────────────────────────────

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _RowWrapper(
      isLast: isLast,
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.error),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon Box ───────────────────────────────────────────────────────────────

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }
}

// ── Row Wrapper ────────────────────────────────────────────────────────────

class _RowWrapper extends StatelessWidget {
  const _RowWrapper({
    required this.child,
    this.isLast = false,
    this.onTap,
    this.borderRadius,
  });
  final Widget child;
  final bool isLast;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  child: child,
                ),
              )
            : child,
        if (!isLast)
          const Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

// ── Divider ────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: AppColors.divider,
    );
  }
}

// ── Profile Header Shimmer ─────────────────────────────────────────────────

class _ProfileHeaderShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.shimmerBase,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: AppColors.shimmerHighlight);
  }
}
