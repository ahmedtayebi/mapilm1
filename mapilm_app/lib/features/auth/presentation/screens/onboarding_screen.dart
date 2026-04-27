import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../widgets/premium_button_widget.dart';

// ── Slide data ─────────────────────────────────────────────────────────────

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.painter,
    required this.accentColor,
  });
  final String title;
  final String subtitle;
  final CustomPainter painter;
  final Color accentColor;
}

final _slides = [
  _SlideData(
    title: 'تواصل مع من تحب',
    subtitle: 'راسل أصدقاءك وعائلتك\nبكل سهولة ويسر',
    painter: _ChatIllustrationPainter(),
    accentColor: AppColors.primary,
  ),
  _SlideData(
    title: 'رسائل آمنة ومشفرة',
    subtitle: 'محادثاتك محمية بتشفير\nمن طرف لطرف',
    painter: _ShieldIllustrationPainter(),
    accentColor: const Color(0xFF7C3AED),
  ),
  _SlideData(
    title: 'شارك لحظاتك',
    subtitle: 'أرسل صوراً ورسائل صوتية\nبضغطة واحدة',
    painter: _MediaIllustrationPainter(),
    accentColor: const Color(0xFF0891B2),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _illustrationAnim;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _illustrationAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _illustrationAnim.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go(AppRoutes.phone);
    }
  }

  void _skip() => context.go(AppRoutes.phone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background decorative blobs
          Positioned(
            top: -60,
            left: -60,
            child: _buildBlob(200, AppColors.primary.withOpacity(0.06)),
          ),
          Positioned(
            bottom: 80,
            right: -80,
            child: _buildBlob(240, AppColors.primary.withOpacity(0.04)),
          ),
          Column(
            children: [
              // Skip button row
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _slides.length - 1)
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.grey500,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            AppStrings.skip,
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.grey400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _SlidePage(
                    slide: _slides[i],
                    animController: _illustrationAnim,
                    isActive: i == _currentPage,
                  ),
                ),
              ),
              // Bottom section
              _buildBottom(),
              SafeArea(
                top: false,
                child: const SizedBox(height: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    final isLast = _currentPage == _slides.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          // Custom dot indicator
          _DotIndicator(count: _slides.length, current: _currentPage),
          const SizedBox(height: 32),
          PremiumButtonWidget(
            text: isLast ? AppStrings.getStarted : AppStrings.next,
            onPressed: _goNext,
          ).animate(key: ValueKey(_currentPage)).fadeIn(duration: 200.ms),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ── Slide page widget ──────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  const _SlidePage({
    required this.slide,
    required this.animController,
    required this.isActive,
  });

  final _SlideData slide;
  final AnimationController animController;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration area
          SizedBox(
            width: double.infinity,
            height: 260,
            child: AnimatedBuilder(
              animation: animController,
              builder: (context, _) => CustomPaint(
                painter: slide.painter,
              ),
            ),
          )
              .animate(key: ValueKey(slide.title))
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1.0, 1.0),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 44),
          // Title
          Text(
            slide.title,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.grey900,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('${slide.title}_title'))
              .fadeIn(delay: 150.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 400.ms),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            slide.subtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.grey500,
              height: 1.8,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('${slide.title}_sub'))
              .fadeIn(delay: 250.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

// ── Dot indicator ──────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.grey300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Custom Painters (Illustrations) ───────────────────────────────────────

class _ChatIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      100,
      Paint()
        ..color = AppColors.primaryLighter
        ..style = PaintingStyle.fill,
    );

    // Glow
    canvas.drawCircle(
      Offset(cx, cy),
      110,
      Paint()
        ..color = AppColors.primary.withOpacity(0.08)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final bubblePaint = Paint()..style = PaintingStyle.fill;

    // Outgoing bubble (right)
    bubblePaint.color = AppColors.primary;
    final outBubble = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - 10, cy - 55, 100, 46),
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(outBubble, bubblePaint);

    // Bubble tail
    final tailPath = Path()
      ..moveTo(cx + 88, cy - 9)
      ..lineTo(cx + 110, cy - 2)
      ..lineTo(cx + 90, cy - 20)
      ..close();
    canvas.drawPath(tailPath, bubblePaint);

    // Text lines in bubble
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 43), Offset(cx + 78, cy - 43), linePaint);
    canvas.drawLine(Offset(cx, cy - 30), Offset(cx + 58, cy - 30), linePaint);

    // Incoming bubble (left)
    bubblePaint.color = Colors.white;
    final inBubble = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - 108, cy + 5, 96, 46),
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(18),
    );
    canvas.drawRRect(
      inBubble,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(inBubble, bubblePaint);

    final tailPath2 = Path()
      ..moveTo(cx - 10, cy + 51)
      ..lineTo(cx - 128, cy + 58)
      ..lineTo(cx - 12, cy + 36)
      ..close();
    canvas.drawPath(tailPath2, bubblePaint);

    // Text lines in incoming
    final linePaint2 = Paint()
      ..color = AppColors.grey300
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 96, cy + 18), Offset(cx - 20, cy + 18), linePaint2);
    canvas.drawLine(Offset(cx - 96, cy + 30), Offset(cx - 36, cy + 30), linePaint2);

    // Small decorative dots
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * math.pi * 2;
      final dx = cx + math.cos(angle) * 128;
      final dy = cy + math.sin(angle) * 100;
      canvas.drawCircle(
        Offset(dx, dy),
        3,
        Paint()..color = AppColors.primary.withOpacity(0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_ChatIllustrationPainter old) => false;
}

class _ShieldIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      100,
      Paint()
        ..color = const Color(0xFFF3F0FF)
        ..style = PaintingStyle.fill,
    );

    // Glow
    canvas.drawCircle(
      Offset(cx, cy),
      112,
      Paint()
        ..color = const Color(0xFF7C3AED).withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Shield
    final shieldPath = Path();
    shieldPath.moveTo(cx, cy - 70);
    shieldPath.cubicTo(cx + 55, cy - 70, cx + 70, cy - 30, cx + 70, cy + 10);
    shieldPath.cubicTo(cx + 70, cy + 50, cx + 35, cy + 75, cx, cy + 80);
    shieldPath.cubicTo(cx - 35, cy + 75, cx - 70, cy + 50, cx - 70, cy + 10);
    shieldPath.cubicTo(cx - 70, cy - 30, cx - 55, cy - 70, cx, cy - 70);

    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = const Color(0xFF7C3AED)
        ..style = PaintingStyle.fill,
    );

    // Shield inner highlight
    final shieldInner = Path();
    shieldInner.moveTo(cx, cy - 52);
    shieldInner.cubicTo(cx + 38, cy - 52, cx + 50, cy - 18, cx + 50, cy + 14);
    shieldInner.cubicTo(cx + 50, cy + 44, cx + 24, cy + 62, cx, cy + 66);
    shieldInner.cubicTo(cx - 24, cy + 62, cx - 50, cy + 44, cx - 50, cy + 14);
    shieldInner.cubicTo(cx - 50, cy - 18, cx - 38, cy - 52, cx, cy - 52);

    canvas.drawPath(
      shieldInner,
      Paint()
        ..color = const Color(0xFF9D67F5)
        ..style = PaintingStyle.fill,
    );

    // Lock icon in shield
    final lockPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Lock body
    final lockBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 10), width: 36, height: 30),
      const Radius.circular(8),
    );
    canvas.drawRRect(lockBody, Paint()..color = Colors.white);
    canvas.drawRRect(lockBody, lockPaint);

    // Lock shackle
    final shacklePath = Path();
    shacklePath.addArc(
      Rect.fromCenter(center: Offset(cx, cy - 2), width: 24, height: 28),
      math.pi,
      math.pi,
    );
    canvas.drawPath(shacklePath, lockPaint);

    // Keyhole
    canvas.drawCircle(Offset(cx, cy + 8), 5, Paint()..color = const Color(0xFF7C3AED));
    canvas.drawLine(
      Offset(cx, cy + 13),
      Offset(cx, cy + 20),
      Paint()
        ..color = const Color(0xFF7C3AED)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Orbit rings
    for (var ring = 0; ring < 2; ring++) {
      canvas.drawCircle(
        Offset(cx, cy),
        130 + ring * 16.0,
        Paint()
          ..color = const Color(0xFF7C3AED).withOpacity(0.06 - ring * 0.02)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Sparkle dots
    for (var i = 0; i < 4; i++) {
      final angle = (i / 4) * math.pi * 2 + math.pi / 4;
      final dx = cx + math.cos(angle) * 112;
      final dy = cy + math.sin(angle) * 88;
      canvas.drawCircle(
        Offset(dx, dy),
        4,
        Paint()..color = const Color(0xFF7C3AED).withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_ShieldIllustrationPainter old) => false;
}

class _MediaIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      100,
      Paint()
        ..color = const Color(0xFFE0F5FA)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      112,
      Paint()
        ..color = const Color(0xFF0891B2).withOpacity(0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Photo frame 1 (back, slightly rotated)
    _drawPhotoCard(
      canvas,
      Rect.fromCenter(center: Offset(cx - 30, cy - 20), width: 90, height: 72),
      -0.12,
      const Color(0xFF0891B2).withOpacity(0.6),
      isBack: true,
    );

    // Photo frame 2 (front)
    _drawPhotoCard(
      canvas,
      Rect.fromCenter(center: Offset(cx + 10, cy - 10), width: 90, height: 72),
      0.08,
      const Color(0xFF0891B2),
      isBack: false,
    );

    // Voice wave bars
    final waveColors = [
      const Color(0xFF0891B2).withOpacity(0.3),
      const Color(0xFF0891B2).withOpacity(0.6),
      const Color(0xFF0891B2),
      const Color(0xFF06B6D4),
      const Color(0xFF0891B2),
      const Color(0xFF0891B2).withOpacity(0.6),
      const Color(0xFF0891B2).withOpacity(0.3),
    ];
    final waveHeights = [16.0, 26.0, 38.0, 50.0, 38.0, 26.0, 16.0];
    final waveStartX = cx - 50.0;
    for (var i = 0; i < 7; i++) {
      final barX = waveStartX + i * 16.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(barX, cy + 60),
            width: 8,
            height: waveHeights[i],
          ),
          const Radius.circular(4),
        ),
        Paint()..color = waveColors[i],
      );
    }

    // Decorative plus signs
    final plusPaint = Paint()
      ..color = const Color(0xFF0891B2).withOpacity(0.25)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final angle = (i / 3) * math.pi * 2;
      final px = cx + math.cos(angle) * 120;
      final py = cy + math.sin(angle) * 95;
      canvas.drawLine(Offset(px - 5, py), Offset(px + 5, py), plusPaint);
      canvas.drawLine(Offset(px, py - 5), Offset(px, py + 5), plusPaint);
    }
  }

  void _drawPhotoCard(Canvas canvas, Rect rect, double angle, Color color,
      {required bool isBack}) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(angle);
    canvas.translate(-rect.center.dx, -rect.center.dy);

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    if (isBack) {
      canvas.drawRRect(rrect, Paint()..color = color);
    } else {
      // Card
      canvas.drawRRect(rrect, Paint()..color = Colors.white);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Image placeholder area
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            rect.left + 8,
            rect.top + 8,
            rect.right - 8,
            rect.bottom - 20,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = color.withOpacity(0.2),
      );
      // Mountain icon
      final mountainPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final mPath = Path()
        ..moveTo(rect.left + 14, rect.bottom - 22)
        ..lineTo(rect.left + 30, rect.bottom - 44)
        ..lineTo(rect.left + 46, rect.bottom - 30)
        ..lineTo(rect.left + 58, rect.bottom - 42)
        ..lineTo(rect.left + 76, rect.bottom - 22)
        ..close();
      canvas.drawPath(mPath, mountainPaint);
      // Sun
      canvas.drawCircle(
        Offset(rect.left + 65, rect.top + 18),
        8,
        Paint()..color = const Color(0xFFFFC107),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MediaIllustrationPainter old) => false;
}
