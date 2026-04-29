import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  // Dock height (visible bar) + 6px breathing slack above. Plus a 12px
  // halo for the floating indicator dot that lives above the dock.
  static const double kDockHeight = 68.0;
  static const double kDockBreathing = 6.0;
  static const double kDockHalo = 12.0;
  static const double kNavBarTotal = kDockHeight + kDockBreathing + kDockHalo;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Extend BOTH padding.bottom and viewPadding.bottom so:
    //  - SafeArea reserves space (padding)
    //  - Scaffold.floatingActionButton positions above the dock (viewPadding)
    final extraBottomPad = kNavBarTotal + mq.padding.bottom;
    final extraViewPad = kNavBarTotal + mq.viewPadding.bottom;
    return Stack(
      children: [
        // Only the page content sees the extended insets. The dock itself
        // must read the REAL system insets to size its gesture-bar extension
        // correctly, so it stays outside this MediaQuery.
        MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(bottom: extraBottomPad),
            viewPadding: mq.viewPadding.copyWith(bottom: extraViewPad),
          ),
          child: navigationShell,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _AuroraDock(
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Aurora Dock ───────────────────────────────────────────────────────────
//
// Pinned to the bottom edge. Items always render in LTR order so that the
// active pill (positioned via `Positioned.left`) lines up with the correct
// branch under both LTR and RTL document directions. Icons are universal;
// labels are short single tokens that render correctly in either direction.

const _kDockItems = <_DockItem>[
  _DockItem(
    icon: Icons.bubble_chart_rounded,
    inactiveIcon: Icons.bubble_chart_outlined,
    label: 'المحادثات',
  ),
  _DockItem(
    icon: Icons.diversity_3_rounded,
    inactiveIcon: Icons.diversity_3_outlined,
    label: 'الجهات',
  ),
  _DockItem(
    icon: Icons.tune_rounded,
    inactiveIcon: Icons.tune_outlined,
    label: 'الإعدادات',
  ),
];

class _DockItem {
  const _DockItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
  });
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
}

class _AuroraDock extends StatelessWidget {
  const _AuroraDock({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final extension = bottomPad > 0 ? bottomPad : 6.0;
    const dockH = MainShell.kDockHeight;
    const halo = MainShell.kDockHalo;
    const sidePad = 10.0;

    // Force LTR so `Positioned.left` aligns with the correct visual slot
    // under both LTR and RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullW = constraints.maxWidth;
          final innerW = fullW - sidePad * 2;
          final itemW = innerW / _kDockItems.length;
          return SizedBox(
            height: halo + dockH + extension,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Dock background — flush with screen bottom, rounded top.
                //    Background color extends through the gesture-bar inset.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: dockH + extension,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.94),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white,
                              width: 1.2,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withOpacity(0.12),
                              blurRadius: 26,
                              offset: const Offset(0, -8),
                            ),
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 2. Active aurora pill — positioned in outer stack coords so
                //    it animates smoothly across slots.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  left: sidePad + itemW * currentIndex,
                  bottom: extension + 6,
                  height: dockH - 12,
                  width: itemW,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.auroraStops,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.36),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 3. Buttons row — sits in the dock's icon zone, above the
                //    gesture-bar extension.
                Positioned(
                  left: sidePad,
                  right: sidePad,
                  bottom: extension + 6,
                  height: dockH - 12,
                  child: Row(
                    children: List.generate(_kDockItems.length, (i) {
                      final active = i == currentIndex;
                      return Expanded(
                        child: _DockButton(
                          item: _kDockItems[i],
                          active: active,
                          onTap: () {
                            if (!active) HapticFeedback.selectionClick();
                            onTap(i);
                          },
                        ),
                      );
                    }),
                  ),
                ),
                // 4. Floating indicator bar — distinctive frame detail that
                //    breaks the dock's top edge.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  left: sidePad + itemW * currentIndex + itemW / 2 - 14,
                  width: 28,
                  height: halo,
                  child: const _IndicatorDot(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IndicatorDot extends StatelessWidget {
  const _IndicatorDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 4,
        width: 22,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.auroraStops),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  const _DockButton({
    required this.item,
    required this.active,
    required this.onTap,
  });
  final _DockItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: widget.active
                ? _ActiveContent(
                    key: const ValueKey('active'),
                    item: widget.item,
                  )
                : _InactiveContent(
                    key: const ValueKey('inactive'),
                    item: widget.item,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActiveContent extends StatelessWidget {
  const _ActiveContent({super.key, required this.item});
  final _DockItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, color: Colors.white, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InactiveContent extends StatelessWidget {
  const _InactiveContent({super.key, required this.item});
  final _DockItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.inactiveIcon, color: AppColors.inkSoft, size: 22),
        const SizedBox(height: 3),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.inkSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
