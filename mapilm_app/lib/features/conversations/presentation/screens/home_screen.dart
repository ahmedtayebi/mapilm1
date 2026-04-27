import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/conversations_provider.dart';
import '../widgets/conversation_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isSearching = false;
  String _searchQuery = '';
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldExtend = _scrollController.offset < 60;
    if (shouldExtend != _isFabExtended) {
      setState(() => _isFabExtended = shouldExtend);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification) {
                final shouldExtend = (n.metrics.pixels) < 60;
                if (shouldExtend != _isFabExtended) {
                  setState(() => _isFabExtended = shouldExtend);
                }
              }
              return false;
            },
            child: Column(
              children: [
                // Custom App Bar
                _HomeAppBar(
                  user: user,
                  isSearching: _isSearching,
                  searchController: _searchController,
                  onSearchToggle: _toggleSearch,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onNewChat: () => context.push(AppRoutes.contacts),
                  onProfileTap: () =>
                      context.push(AppRoutes.profile, extra: user?.uid),
                ),
                // Custom Tab Row
                _TabRow(controller: _tabController),
                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _ConversationList(
                        key: const PageStorageKey('all'),
                        conversationsAsync: conversations,
                        filter: null,
                        searchQuery: _searchQuery,
                      ),
                      _ConversationList(
                        key: const PageStorageKey('groups'),
                        conversationsAsync: conversations,
                        filter: ConversationType.group,
                        searchQuery: _searchQuery,
                      ),
                    ],
                  ),
                ),
                // Bottom padding for floating nav
                const SizedBox(height: 80),
              ],
            ),
          ),
          // Floating bottom nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _FloatingBottomNav(currentIndex: 0),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildFab() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: _isFabExtended
          ? FloatingActionButton.extended(
              heroTag: 'home_fab',
              onPressed: () => context.push(AppRoutes.contacts),
              backgroundColor: AppColors.primary,
              elevation: 6,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              icon: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 20),
              label: Text(
                AppStrings.newChat,
                style: AppTypography.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ).animate().scale(
                begin: const Offset(0.8, 0.8),
                delay: 400.ms,
                curve: Curves.easeOutBack,
              )
          : FloatingActionButton(
              heroTag: 'home_fab',
              onPressed: () => context.push(AppRoutes.contacts),
              backgroundColor: AppColors.primary,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 22),
            ),
    );
  }
}

// ── Custom App Bar ─────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({
    required this.user,
    required this.isSearching,
    required this.searchController,
    required this.onSearchToggle,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onProfileTap,
  });

  final dynamic user;
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewChat;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPad),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // User avatar (tap → profile)
                GestureDetector(
                  onTap: onProfileTap,
                  child: AppAvatar(
                    imageUrl: null,
                    name: user?.displayName ?? '?',
                    radius: 19,
                    showOnlineIndicator: true,
                    isOnline: true,
                  ),
                ),
                // Center logo
                Expanded(
                  child: Center(
                    child: Text(
                      'Mapilm',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Action icons
                _AppBarIcon(
                  icon: isSearching
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  onTap: onSearchToggle,
                ),
                const SizedBox(width: 4),
                _AppBarIcon(
                  icon: Icons.edit_square,
                  onTap: onNewChat,
                ),
              ],
            ),
          ),
          // Animated search bar
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: isSearching
                ? Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: AppTypography.bodyMedium,
                        textDirection: TextDirection.rtl,
                        cursorColor: AppColors.primary,
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن محادثة...',
                          hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.grey400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppColors.grey400,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

// ── Custom Tab Row ─────────────────────────────────────────────────────────

class _TabRow extends StatefulWidget {
  const _TabRow({required this.controller});
  final TabController controller;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.index;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _TabItem(
              label: AppStrings.conversations,
              active: current == 0,
              onTap: () => widget.controller.animateTo(0),
            ),
            _TabItem(
              label: 'المجموعات',
              active: current == 1,
              onTap: () => widget.controller.animateTo(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTypography.labelMedium.copyWith(
                color: active ? Colors.white : AppColors.grey500,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conversation List ──────────────────────────────────────────────────────

class _ConversationList extends ConsumerWidget {
  const _ConversationList({
    super.key,
    required this.conversationsAsync,
    required this.filter,
    required this.searchQuery,
  });

  final AsyncValue<List<ConversationEntity>> conversationsAsync;
  final ConversationType? filter;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return conversationsAsync.when(
      loading: () => const ConversationShimmer(),
      error: (e, _) => _ErrorState(
        onRetry: () => ref.read(conversationsProvider.notifier).refresh(),
      ),
      data: (conversations) {
        var filtered = filter != null
            ? conversations.where((c) => c.type == filter).toList()
            : conversations;

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where((c) =>
                  (c.name?.toLowerCase().contains(q) ?? false) ||
                  c.participants.any((p) =>
                      (p.name?.toLowerCase().contains(q) ?? false)))
              .toList();
        }

        if (filtered.isEmpty) {
          return _EmptyConversations(
            isFiltered: searchQuery.isNotEmpty || filter != null,
            onNewChat: () => context.push(AppRoutes.contacts),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final conv = filtered[i];
              return Column(
                children: [
                  ConversationTile(
                    conversation: conv,
                    onArchive: () {/* archive */},
                    onDelete: () {/* delete */},
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: i * 35),
                        duration: 300.ms,
                      ),
                  if (i < filtered.length - 1)
                    const Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: AppColors.divider,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({
    required this.isFiltered,
    required this.onNewChat,
  });
  final bool isFiltered;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.7, 0.7),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'لا توجد نتائج' : AppStrings.noConversations,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.grey800,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'حاول البحث بكلمة مختلفة'
                  : AppStrings.noConversationsSubtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.grey500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 280.ms),
            if (!isFiltered) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: onNewChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'بدء محادثة',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3),
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
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(AppStrings.somethingWrong, style: AppTypography.bodyMedium),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}

// ── Floating Bottom Navigation ─────────────────────────────────────────────

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPad),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2038F5).withOpacity(0.14),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              inactiveIcon: Icons.chat_bubble_outline_rounded,
              label: AppStrings.conversations,
              active: currentIndex == 0,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.contacts_rounded,
              inactiveIcon: Icons.contacts_outlined,
              label: AppStrings.contacts,
              active: currentIndex == 1,
              onTap: () => context.push(AppRoutes.contacts),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              inactiveIcon: Icons.settings_outlined,
              label: AppStrings.settings,
              active: currentIndex == 2,
              onTap: () => context.push(AppRoutes.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.active ? widget.icon : widget.inactiveIcon,
                  size: 24,
                  color: widget.active ? AppColors.primary : AppColors.grey400,
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppTypography.labelSmall.copyWith(
                    color:
                        widget.active ? AppColors.primary : AppColors.grey400,
                    fontWeight:
                        widget.active ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 10,
                  ),
                  child: Text(widget.label),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: widget.active ? 20 : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
