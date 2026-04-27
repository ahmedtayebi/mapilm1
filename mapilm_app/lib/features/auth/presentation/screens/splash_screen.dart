import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2038F5),
              Color(0xFF1429C8),
              Color(0xFF0D1B8E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Floating particles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) => CustomPaint(
                  painter: _ParticlePainter(_particleController.value),
                ),
              ),
            ),
            // Radial glow behind logo
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) => Container(
                  width: 220 + _pulseController.value * 30,
                  height: 220 + _pulseController.value * 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.08 * (1 - _pulseController.value * 0.3)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo container
                  _LogoWidget()
                      .animate()
                      .scale(
                        begin: const Offset(0.4, 0.4),
                        end: const Offset(1.0, 1.0),
                        duration: 900.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 500.ms),
                  const SizedBox(height: 32),
                  // App name
                  Text(
                    'مابيلم',
                    style: AppTypography.displaySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 700.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        delay: 500.ms,
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 10),
                  Text(
                    'تواصل بلا حدود',
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.72),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 750.ms, duration: 600.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.18),
            blurRadius: 40,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFF2038F5).withOpacity(0.6),
            blurRadius: 60,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'M',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 24,
              ),
              Shadow(
                color: const Color(0xFFB0BFFF).withOpacity(0.6),
                blurRadius: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Particle System ────────────────────────────────────────────────────────

class _ParticleData {
  const _ParticleData({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.drift,
  });
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
  final double drift;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t);
  final double t;

  static final _particles = List<_ParticleData>.unmodifiable(
    List.generate(22, (i) {
      final rand = math.Random(i * 31 + 7);
      return _ParticleData(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        radius: rand.nextDouble() * 3.5 + 1.5,
        speed: rand.nextDouble() * 0.18 + 0.06,
        phase: rand.nextDouble(),
        drift: (rand.nextDouble() - 0.5) * 0.1,
      );
    }),
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final progress = (t * p.speed + p.phase) % 1.0;
      final y = size.height * (1.0 - progress);
      final x = size.width * p.x +
          math.sin((t * 2 + p.phase) * math.pi * 2) * 25 * p.drift.abs();

      final opacity = progress < 0.15
          ? progress / 0.15
          : progress > 0.85
              ? (1.0 - progress) / 0.15
              : 1.0;

      canvas.drawCircle(
        Offset(x.clamp(0, size.width), y.clamp(0, size.height)),
        p.radius,
        Paint()
          ..color = Colors.white.withOpacity(opacity * 0.35)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
