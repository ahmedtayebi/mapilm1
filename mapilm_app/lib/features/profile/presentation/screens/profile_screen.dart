import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../providers/profile_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  String? _inviteLink;

  bool get _isOwnProfile {
    final uid = ref.read(currentUserProvider)?.uid;
    return widget.userId == null || widget.userId == uid;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: meAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.somethingWrong,
                  style: AppTypography.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(meProvider),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
        data: (user) => _buildContent(context, user),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> user) {
    const headerHeight = 310.0;
    const statsCardH = 88.0;
    const statsOverlap = 44.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Header + stats card straddle
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient header
              _GradientHeader(
                height: headerHeight,
                user: user,
                isOwnProfile: _isOwnProfile,
                pulseCtrl: _pulseCtrl,
                onEditTap: () => _openEdit(context, user),
                onBackTap: () => context.pop(),
              ),
              // Floating stats card
              Positioned(
                bottom: -(statsCardH - statsOverlap),
                left: 20,
                right: 20,
                child: _StatsCard(user: user)
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.2),
              ),
            ],
          ),
          // Space for the hanging card
          SizedBox(height: statsCardH - statsOverlap + 16),
          // Body sections
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (_isOwnProfile) ...[
                  _buildAccountSection(context, user),
                  const SizedBox(height: 12),
                  _buildInviteSection(context),
                  const SizedBox(height: 12),
                  _buildPrivacySection(context),
                  const SizedBox(height: 12),
                  _buildLogoutSection(context),
                ] else ...[
                  _buildOtherUserSection(context, user),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
      BuildContext context, Map<String, dynamic> user) {
    return _SectionCard(
      title: 'الحساب',
      children: [
        _SectionRow(
          icon: Icons.person_outline_rounded,
          label: 'تعديل الاسم',
          value: user['name'] as String? ?? '',
          onTap: () => _openEdit(context, user),
        ),
        _SectionRow(
          icon: Icons.camera_alt_outlined,
          label: 'تعديل الصورة',
          onTap: () => _openEdit(context, user),
        ),
        _SectionRow(
          icon: Icons.mood_rounded,
          label: 'تعديل الحالة',
          value: user['bio'] as String? ?? '',
          onTap: () => _openEdit(context, user),
          isLast: true,
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildInviteSection(BuildContext context) {
    return _SectionCard(
      title: 'ادعُ أصدقاءك',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'شارك Mapilm مع أصدقائك وعائلتك',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.grey500,
                ),
              ),
              const SizedBox(height: 14),
              if (_inviteLink != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _inviteLink!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _inviteLink!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text(AppStrings.copiedToClipboard),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Share.share(_inviteLink!),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('مشاركة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generateLink,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('إنشاء رابط دعوة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 440.ms).slideY(begin: 0.1);
  }

  Widget _buildPrivacySection(BuildContext context) {
    return _SectionCard(
      title: AppStrings.privacy,
      children: [
        _SectionRow(
          icon: Icons.access_time_rounded,
          label: 'آخر ظهور',
          value: 'الجميع',
          onTap: () {},
        ),
        _SectionRow(
          icon: Icons.image_rounded,
          label: 'الصورة الشخصية',
          value: 'الجميع',
          onTap: () {},
          isLast: true,
        ),
      ],
    ).animate().fadeIn(delay: 480.ms).slideY(begin: 0.1);
  }

  Widget _buildLogoutSection(BuildContext context) {
    return _SectionCard(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final confirmed = await ConfirmationDialog.show(
                context,
                title: AppStrings.logout,
                message: AppStrings.logoutConfirm,
                confirmLabel: AppStrings.logout,
                isDestructive: true,
                icon: Icons.logout_rounded,
              );
              if (confirmed && context.mounted) {
                await ref.read(meProvider.notifier).logout();
                if (context.mounted) context.go('/');
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    AppStrings.logout,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 520.ms).slideY(begin: 0.1);
  }

  Widget _buildOtherUserSection(
      BuildContext context, Map<String, dynamic> user) {
    return _SectionCard(
      children: [
        _SectionRow(
          icon: Icons.block_rounded,
          label: AppStrings.blockUser,
          iconColor: AppColors.error,
          labelColor: AppColors.error,
          onTap: () {},
        ),
        _SectionRow(
          icon: Icons.flag_rounded,
          label: AppStrings.reportUser,
          iconColor: AppColors.warning,
          labelColor: AppColors.warning,
          onTap: () {},
          isLast: true,
        ),
      ],
    );
  }

  void _openEdit(BuildContext context, Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(currentUser: user),
      ),
    );
  }

  Future<void> _generateLink() async {
    final link = await ref.read(meProvider.notifier).generateInviteLink();
    if (link != null) setState(() => _inviteLink = link);
  }
}

// ── Gradient Header ────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.height,
    required this.user,
    required this.isOwnProfile,
    required this.pulseCtrl,
    required this.onEditTap,
    required this.onBackTap,
  });

  final double height;
  final Map<String, dynamic> user;
  final bool isOwnProfile;
  final AnimationController pulseCtrl;
  final VoidCallback onEditTap;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2038F5), Color(0xFF1429C8), Color(0xFF0D1B8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Back + edit row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      _HeaderBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: onBackTap),
                      const Spacer(),
                      if (isOwnProfile)
                        _HeaderBtn(
                          icon: Icons.edit_rounded,
                          onTap: onEditTap,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // Pulsing glow + avatar
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (context, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      Container(
                        width: 128 + pulseCtrl.value * 12,
                        height: 128 + pulseCtrl.value * 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            0.08 * (1 - pulseCtrl.value * 0.4),
                          ),
                        ),
                      ),
                      // Animated border ring
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              0.5 + pulseCtrl.value * 0.3,
                            ),
                            width: 2.5,
                          ),
                        ),
                      ),
                      // Avatar
                      child!,
                    ],
                  ),
                  child: AppAvatar(
                    imageUrl: user['avatar_url'] as String?,
                    name: user['name'] as String?,
                    radius: 50,
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        duration: 600.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(),
                ),
                const SizedBox(height: 14),
                // Name
                Text(
                  user['name'] as String? ?? '',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                const SizedBox(height: 4),
                // Phone
                Text(
                  user['phone'] as String? ?? '',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textDirection: TextDirection.ltr,
                ).animate().fadeIn(delay: 250.ms),
                // Bio/status
                if (user['bio'] != null &&
                    (user['bio'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user['bio'] as String,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ).animate().fadeIn(delay: 300.ms),
                ],
                const SizedBox(height: 14),
                // Edit profile pill button
                if (isOwnProfile)
                  GestureDetector(
                    onTap: onEditTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.5),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Text(
                        AppStrings.editProfile,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 52), // space for stats card
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ── Stats Card ─────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final createdAt = user['created_at'] != null
        ? DateTime.tryParse(user['created_at'] as String)
        : null;
    final joinedStr = createdAt != null
        ? DateFormat('MMM yyyy', 'ar').format(createdAt)
        : '–';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2038F5).withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              _StatItem(
                value: '${user['conversations_count'] ?? 0}',
                label: 'محادثة',
              ),
              _VertDivider(),
              _StatItem(
                value: '${user['groups_count'] ?? 0}',
                label: 'مجموعة',
              ),
              _VertDivider(),
              _StatItem(value: joinedStr, label: 'تاريخ الانضمام'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.grey500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }
}

// ── Section Card ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                title!,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.isLast = false,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final bool isLast;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.primary)
                          .withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: iconColor ?? AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.grey800,
                      ),
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.grey400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: AppColors.grey300,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 66, endIndent: 16),
      ],
    );
  }
}
