import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// PresenceOrb — the new avatar primitive for the Mapilm aurora redesign.
///
/// A circular avatar wrapped in a gradient halo. When [isOnline] is true,
/// a slow rotating aurora conic gradient animates around the perimeter.
/// When offline, the ring is a soft static stroke.
///
/// [radius] is the inner avatar radius. Total widget size is
/// `(radius + ringWidth + ringGap) * 2`.
class PresenceOrb extends StatefulWidget {
  const PresenceOrb({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
    this.isOnline = false,
    this.ringWidth = 2.0,
    this.ringGap = 3.0,
    this.colors,
    this.showRing = true,
    this.tint,
  });

  final String? imageUrl;
  final String? name;
  final double radius;
  final bool isOnline;
  final double ringWidth;
  final double ringGap;

  /// Override the gradient colors. Defaults to [AppColors.auroraStops].
  final List<Color>? colors;

  /// When false, no ring is drawn (used inside group avatar clusters).
  final bool showRing;

  /// Solid fallback color for the avatar when no image (overrides hash color).
  final Color? tint;

  @override
  State<PresenceOrb> createState() => _PresenceOrbState();
}

class _PresenceOrbState extends State<PresenceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.isOnline && widget.showRing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant PresenceOrb old) {
    super.didUpdateWidget(old);
    if (widget.isOnline != old.isOnline || widget.showRing != old.showRing) {
      if (widget.isOnline && widget.showRing) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.showRing ? widget.ringWidth + widget.ringGap : 0.0;
    final outer = (widget.radius + ring) * 2;
    final colors = widget.colors ?? AppColors.auroraStops;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.showRing)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                size: Size(outer, outer),
                painter: _RingPainter(
                  rotation: _ctrl.value * 2 * math.pi,
                  width: widget.ringWidth,
                  gap: widget.ringGap,
                  colors: colors,
                  isOnline: widget.isOnline,
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(ring),
              child: _Inner(
                imageUrl: widget.imageUrl,
                name: widget.name,
                radius: widget.radius,
                tint: widget.tint,
              ),
            ),
          ),
          if (widget.isOnline && widget.showRing)
            Positioned(
              right: 1,
              bottom: 1,
              child: _LiveDot(size: math.max(8, widget.radius * 0.32)),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.rotation,
    required this.width,
    required this.gap,
    required this.colors,
    required this.isOnline,
  });

  final double rotation;
  final double width;
  final double gap;
  final List<Color> colors;
  final bool isOnline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - width / 2;

    if (isOnline) {
      final shader = SweepGradient(
        colors: [...colors, colors.first],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      final paint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, paint);
    } else {
      final paint = Paint()
        ..color = AppColors.glassBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.rotation != rotation ||
      old.isOnline != isOnline ||
      old.colors != colors;
}

class _Inner extends StatelessWidget {
  const _Inner({
    required this.imageUrl,
    required this.name,
    required this.radius,
    required this.tint,
  });

  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (_, provider) => CircleAvatar(
          radius: radius,
          backgroundImage: provider,
        ),
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initials = _initials(name);
    final bg = tint ?? _hashColor(name);
    final fontSize = radius * 0.62;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(bg, Colors.white, 0.05)!,
            Color.lerp(bg, AppColors.ink, 0.18)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  static Color _hashColor(String? name) {
    const palette = [
      AppColors.primary,
      AppColors.violet,
      AppColors.rose,
      AppColors.peach,
      AppColors.mint,
      AppColors.amber,
      Color(0xFF4F46E5),
      Color(0xFF0891B2),
    ];
    if (name == null || name.isEmpty) return palette[0];
    return palette[name.codeUnitAt(0) % palette.length];
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.online,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.pearl, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.online.withOpacity(0.45),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
