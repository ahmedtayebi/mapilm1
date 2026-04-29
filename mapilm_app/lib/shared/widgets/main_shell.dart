import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  // Nav bar total height used by child screens for bottom padding.
  static const double kNavBarTotal = 88.0; // 64 height + 12 margin + 12 slack

  @override
  Widget build(BuildContext context) {
    // Extend MediaQuery bottom padding so Scaffold-based screens
    // (SafeArea, FAB positioning, keyboard avoidance) all respect the nav bar.
    final mq = MediaQuery.of(context);
    final extraBottom = kNavBarTotal + mq.padding.bottom;
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(bottom: extraBottom),
      ),
      child: Stack(
        children: [
          navigationShell,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PersistentBottomNav(
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersistentBottomNav extends StatelessWidget {
  const _PersistentBottomNav({
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final void Function(int) onTap;

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
              color: AppColors.primary.withOpacity(0.14),
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
          children: [
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              inactiveIcon: Icons.chat_bubble_outline_rounded,
              label: 'المحادثات',
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.contacts_rounded,
              inactiveIcon: Icons.contacts_outlined,
              label: 'جهات الاتصال',
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              inactiveIcon: Icons.settings_outlined,
              label: 'الإعدادات',
              active: currentIndex == 2,
              onTap: () => onTap(2),
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    widget.active ? widget.icon : widget.inactiveIcon,
                    key: ValueKey(widget.active),
                    size: 24,
                    color: widget.active ? AppColors.primary : AppColors.grey400,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppTypography.labelSmall.copyWith(
                    color: widget.active ? AppColors.primary : AppColors.grey400,
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
