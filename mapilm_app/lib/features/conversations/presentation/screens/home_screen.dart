import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/presence_orb.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/conversations_provider.dart';
import '../widgets/conversation_tile.dart';

/// HomeScreen — Mapilm aurora redesign.
///
/// Big editorial greeting, ambient aurora gradient, "Active now" presence
/// carousel, segmented filter pill, glass card conversation list.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _Segment _segment = _Segment.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.pearl,
      body: Stack(
        children: [
          const _AuroraBackdrop(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  user: user,
                  onAvatarTap: () =>
                      context.push(AppRoutes.profile, extra: user?.uid),
                  onCompose: () => context.go(AppRoutes.contacts),
                  searchController: _searchController,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                ),
                _ActiveNowStrip(conversations: conversations),
                _SegmentBar(
                  selected: _segment,
                  onChanged: (s) => setState(() => _segment = s),
                ),
                Expanded(
                  child: _List(
                    conversationsAsync: conversations,
                    segment: _segment,
                    searchQuery: _searchQuery,
                    onNewChat: () => context.go(AppRoutes.contacts),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Segment { all, groups, pinned }

// ── Backdrop ──────────────────────────────────────────────────────────────

class _AuroraBackdrop extends StatelessWidget {
  const _AuroraBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top-end aurora bloom.
            PositionedDirectional(
              top: -120,
              end: -100,
              child: _Bloom(
                size: 360,
                colors: const [
                  Color(0x552038F5),
                  Color(0x117C5CFF),
                  Color(0x00000000),
                ],
              ),
            ),
            // Lower-start warm bloom.
            PositionedDirectional(
              top: 220,
              start: -160,
              child: _Bloom(
                size: 320,
                colors: const [
                  Color(0x33FF8A65),
                  Color(0x11FF6B9B),
                  Color(0x00000000),
                ],
              ),
            ),
            // Subtle grain via dotted gradient overlay.
            const Positioned.fill(child: _Grain()),
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

class _Grain extends StatelessWidget {
  const _Grain();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GrainPainter());
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink.withOpacity(0.025);
    final rng = math.Random(42);
    for (var i = 0; i < 220; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onAvatarTap,
    required this.onCompose,
    required this.searchController,
    required this.onSearchChanged,
  });

  final User? user;
  final VoidCallback onAvatarTap;
  final VoidCallback onCompose;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();
    final displayName = user?.displayName ?? '';
    final fallback = user?.phoneNumber ?? '';
    final firstName =
        displayName.isNotEmpty ? displayName.split(' ').first : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: PresenceOrb(
                  imageUrl: user?.photoURL,
                  name: displayName.isNotEmpty ? displayName : fallback,
                  radius: 22,
                  isOnline: true,
                  ringWidth: 2.2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstName.isEmpty ? 'مرحباً' : firstName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _CompactIconButton(
                icon: Icons.notifications_none_rounded,
                onTap: () {},
                badge: true,
              ),
              const SizedBox(width: 8),
              _ComposeButton(onTap: onCompose),
            ],
          ).animate().fadeIn(duration: 360.ms).slideY(
                begin: -0.15,
                duration: 380.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 16),
          _SearchPill(
            controller: searchController,
            onChanged: onSearchChanged,
          ).animate().fadeIn(delay: 80.ms, duration: 380.ms).slideY(
                begin: 0.2,
                delay: 80.ms,
                duration: 380.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير ·';
    if (h < 18) return 'مساء النور ·';
    return 'مساء الخير ·';
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 6, 0),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              onChanged: onChanged,
              cursorColor: AppColors.primary,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث عن شخص أو مجموعة',
                hintStyle: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted.withOpacity(0.85),
                ),
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.ink.withOpacity(0.045),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 18,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: AppColors.inkSoft),
          ),
          if (badge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.rose,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.pearl, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.auroraStops,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.32),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ── Active Now ────────────────────────────────────────────────────────────

class _ActiveNowStrip extends StatelessWidget {
  const _ActiveNowStrip({required this.conversations});
  final AsyncValue<List<ConversationEntity>> conversations;

  @override
  Widget build(BuildContext context) {
    final list = conversations.valueOrNull ?? const [];
    final currentUserId = '';
    final online = <UserEntity>{};
    for (final c in list) {
      for (final p in c.participants) {
        if (p.id != currentUserId && p.isOnline) online.add(p);
      }
    }
    if (online.isEmpty) return const SizedBox(height: 8);
    final users = online.toList();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        itemCount: users.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          if (i == 0) return const _StoryAddTile();
          final u = users[i - 1];
          return _StoryTile(user: u)
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: math.min(i, 8) * 40),
                duration: 280.ms,
              )
              .slideX(begin: 0.2, duration: 320.ms);
        },
      ),
    );
  }
}

class _StoryAddTile extends StatelessWidget {
  const _StoryAddTile();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: const Icon(
            Icons.add_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'حالتك',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.user});
  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          PresenceOrb(
            imageUrl: user.avatarUrl,
            name: user.name ?? user.phone,
            radius: 26,
            isOnline: user.isOnline,
          ),
          const SizedBox(height: 8),
          Text(
            (user.name ?? user.phone).split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segment Bar ───────────────────────────────────────────────────────────

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.selected, required this.onChanged});
  final _Segment selected;
  final ValueChanged<_Segment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          _SegChip(
            label: 'الكل',
            active: selected == _Segment.all,
            onTap: () => onChanged(_Segment.all),
          ),
          const SizedBox(width: 8),
          _SegChip(
            label: 'المجموعات',
            active: selected == _Segment.groups,
            onTap: () => onChanged(_Segment.groups),
            icon: Icons.diversity_3_rounded,
          ),
          const SizedBox(width: 8),
          _SegChip(
            label: 'المثبّت',
            active: selected == _Segment.pinned,
            onTap: () => onChanged(_Segment.pinned),
            icon: Icons.push_pin_rounded,
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 14 : 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: AppColors.auroraStops,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active
                ? Colors.transparent
                : AppColors.glassBorder,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: active ? Colors.white : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.inkSoft,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────

class _List extends ConsumerWidget {
  const _List({
    required this.conversationsAsync,
    required this.segment,
    required this.searchQuery,
    required this.onNewChat,
  });

  final AsyncValue<List<ConversationEntity>> conversationsAsync;
  final _Segment segment;
  final String searchQuery;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return conversationsAsync.when(
      loading: () => const ConversationShimmer(),
      error: (e, _) => _ErrorState(
        onRetry: () => ref.read(conversationsProvider.notifier).refresh(),
      ),
      data: (conversations) {
        var filtered = conversations.where((c) {
          switch (segment) {
            case _Segment.all:
              return true;
            case _Segment.groups:
              return c.isGroup;
            case _Segment.pinned:
              return c.isPinned;
          }
        }).toList();

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where((c) =>
                  (c.name?.toLowerCase().contains(q) ?? false) ||
                  c.participants.any(
                      (p) => (p.name?.toLowerCase().contains(q) ?? false)))
              .toList();
        }

        if (filtered.isEmpty) {
          return _EmptyState(
            isFiltered: searchQuery.isNotEmpty || segment != _Segment.all,
            onNewChat: onNewChat,
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final conv = filtered[i];
              return ConversationTile(
                conversation: conv,
                onArchive: () {/* archive */},
                onDelete: () {/* delete */},
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: math.min(i, 10) * 30),
                    duration: 280.ms,
                  )
                  .slideY(
                    begin: 0.08,
                    delay: Duration(milliseconds: math.min(i, 10) * 30),
                    duration: 320.ms,
                    curve: Curves.easeOutCubic,
                  );
            },
          ),
        );
      },
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered, required this.onNewChat});
  final bool isFiltered;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.violet.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(
                Icons.bubble_chart_rounded,
                size: 44,
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
            const SizedBox(height: 22),
            Text(
              isFiltered ? 'لا توجد نتائج هنا' : 'الفضاء هادئ الآن',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ).animate().fadeIn(delay: 180.ms),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'حاول كلمة أخرى أو انتقل لقسم مختلف.'
                  : 'ابدأ محادثتك الأولى وامنحها روحاً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.5,
                height: 1.6,
                color: AppColors.inkMuted,
              ),
            ).animate().fadeIn(delay: 260.ms),
            if (!isFiltered) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onNewChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.auroraStops,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'محادثة جديدة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 340.ms).slideY(begin: 0.3),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: AppColors.inkMuted),
          const SizedBox(height: 14),
          const Text(
            'تعذّر الوصول الآن',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
