import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../features/conversations/presentation/widgets/conversation_tile.dart'
    show ChatScreenArgs;
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/profile_provider.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;
  bool _bannerDismissed = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _query = '';
        _searchFocus.unfocus();
      } else {
        Future.delayed(const Duration(milliseconds: 80), () {
          _searchFocus.requestFocus();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Animated search bar
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _searchOpen
                ? _SearchBar(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v),
                    onClose: _toggleSearch,
                  ).animate().fadeIn(duration: 200.ms)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: contactsAsync.when(
              loading: () => _ContactsShimmer(),
              error: (_, __) => EmptyState(
                title: 'حدث خطأ',
                subtitle: 'حاول مجدداً',
                icon: Icons.error_outline_rounded,
                actionLabel: 'إعادة المحاولة',
                onAction: () => ref.invalidate(contactsProvider),
              ),
              data: (contacts) {
                final q = _query.toLowerCase();
                final filtered = q.isEmpty
                    ? contacts
                    : contacts
                        .where((c) =>
                            c.displayName.toLowerCase().contains(q) ||
                            c.phone.contains(q))
                        .toList();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Invite banner
                    if (!_bannerDismissed && q.isEmpty)
                      SliverToBoxAdapter(
                        child: _InviteBanner(
                          onDismiss: () =>
                              setState(() => _bannerDismissed = true),
                          onShare: () =>
                              Share.share('انضم إلى Mapilm — تطبيق المحادثات الأفضل!\nحمّل التطبيق الآن'),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                      ),

                    // "على Mapilm" section
                    if (filtered.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          label: 'على Mapilm',
                          count: filtered.length,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _MapilmContactTile(
                            contact: filtered[i],
                            index: i,
                            onChat: () {
                              context.push(
                                AppRoutes.chat,
                                extra: ChatScreenArgs(
                                  conversationId: filtered[i].id,
                                  participantName: filtered[i].displayName,
                                  participantAvatar: filtered[i].avatarUrl,
                                ),
                              );
                            },
                            onTap: () => context.push(
                              AppRoutes.profile,
                              extra: filtered[i].id,
                            ),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ] else if (q.isNotEmpty) ...[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoResultsState(query: _query),
                      ),
                    ] else ...[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          title: 'لا توجد جهات اتصال',
                          subtitle: 'أضف أصدقاءك وابدأ المحادثة',
                          icon: Icons.person_add_rounded,
                        ),
                      ),
                    ],

                    // "دعوة الأصدقاء" section (always visible when not searching)
                    if (q.isEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(label: 'دعوة الأصدقاء'),
                      ),
                      SliverToBoxAdapter(
                        child: _InviteRow(
                          onInvite: () => Share.share(
                              'انضم إلى Mapilm — تطبيق المحادثات الأفضل!\nحمّل التطبيق الآن'),
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContactSheet(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      )
          .animate()
          .scale(
              begin: const Offset(0, 0),
              delay: 300.ms,
              curve: Curves.easeOutBack)
          .fadeIn(delay: 300.ms),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.white,
      title: const Text(
        'جهات الاتصال',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.grey900,
        ),
      ),
      leading: null,
      actions: [
        // Search toggle
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: IconButton(
            key: ValueKey(_searchOpen),
            icon: Icon(
              _searchOpen ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.grey700,
            ),
            onPressed: _toggleSearch,
          ),
        ),
      ],
    );
  }

  void _showAddContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(
        onAdd: (phone, nickname) {
          ref.read(contactsProvider.notifier).addContact(
                phone: phone,
                nickname: nickname,
              );
        },
      ),
    );
  }
}

// ── Search Bar ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: AppColors.grey900,
                ),
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم أو رقم هاتف...',
                  hintStyle: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.grey400,
                      fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.count});
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.grey500,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mapilm Contact Tile ────────────────────────────────────────────────────

class _MapilmContactTile extends StatelessWidget {
  const _MapilmContactTile({
    required this.contact,
    required this.index,
    required this.onChat,
    required this.onTap,
  });
  final dynamic contact;
  final int index;
  final VoidCallback onChat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: contact.avatarUrl,
                  name: contact.displayName,
                  radius: 24,
                  showOnlineIndicator: true,
                  isOnline: contact.isOnline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.phone,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.grey500,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                // Chat button
                _PillButton(
                  label: 'محادثة',
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: onChat,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.06);
  }
}

// ── Pill Button ────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isGrey = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isGrey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isGrey ? Colors.transparent : AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isGrey ? AppColors.grey300 : AppColors.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isGrey ? AppColors.grey500 : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isGrey ? AppColors.grey600 : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invite Banner ──────────────────────────────────────────────────────────

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.onDismiss, required this.onShare});
  final VoidCallback onDismiss;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2038F5), Color(0xFF1429C8)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              right: 60,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ادعُ أصدقاءك إلى Mapilm',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'شارك التطبيق وتواصل مع الجميع',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: onShare,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'مشاركة الآن',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dismiss
                  IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invite Row (دعوة section) ──────────────────────────────────────────────

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.onInvite});
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.grey500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'دعوة صديق',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'شارك رابط التطبيق مع أصدقائك',
                    style:
                        AppTypography.bodySmall.copyWith(color: AppColors.grey500),
                  ),
                ],
              ),
            ),
            _PillButton(
              label: 'دعوة',
              icon: Icons.send_rounded,
              onTap: onInvite,
              isGrey: true,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

// ── No Results State ───────────────────────────────────────────────────────

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLighter,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.easeOutBack,
                  duration: 350.ms,
                ),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج لـ "$query"',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              'جرّب البحث بطريقة مختلفة',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.grey500),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 160.ms),
          ],
        ),
      ),
    );
  }
}

// ── Add Contact Bottom Sheet ───────────────────────────────────────────────

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.onAdd});
  final void Function(String phone, String? nickname) onAdd;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _phoneCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    widget.onAdd(phone, _nickCtrl.text.trim().isEmpty ? null : _nickCtrl.text.trim());
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'إضافة جهة اتصال',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Phone field
          _SheetInputField(
            controller: _phoneCtrl,
            label: 'رقم الهاتف',
            hint: '+966 5XX XXX XXXX',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 14),
          // Nickname field
          _SheetInputField(
            controller: _nickCtrl,
            label: 'الاسم المستعار (اختياري)',
            hint: 'أدخل اسماً مميزاً',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 28),
          // Add button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'إضافة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOutCubic);
  }
}

class _SheetInputField extends StatelessWidget {
  const _SheetInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textDirection,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.grey600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: AppColors.grey400),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textDirection: textDirection,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: AppColors.grey900,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.grey400,
                        fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Contacts Shimmer ───────────────────────────────────────────────────────

class _ContactsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 120, height: 12, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(
                        width: 80, height: 10, color: Colors.white),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
