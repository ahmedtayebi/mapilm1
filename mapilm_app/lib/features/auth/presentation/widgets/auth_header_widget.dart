import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class AuthHeaderWidget extends StatelessWidget {
  const AuthHeaderWidget({
    super.key,
    required this.icon,
    this.gradientHeight,
    this.showBackButton = false,
    this.onBack,
    this.trailingWidget,
  });

  final Widget icon;
  final double? gradientHeight;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailingWidget;

  static const double _iconDiameter = 80.0;

  @override
  Widget build(BuildContext context) {
    final h = gradientHeight ?? MediaQuery.of(context).size.height * 0.36;

    return SizedBox(
      height: h + _iconDiameter * 0.5,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient with wave at bottom
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              width: double.infinity,
              height: h,
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
                  // Decorative circle top-right
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  // Decorative circle bottom-left
                  Positioned(
                    bottom: 20,
                    left: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  // Navigation row
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          if (showBackButton)
                            _BackButton(onPressed: onBack)
                          else
                            const SizedBox(width: 44),
                          const Spacer(),
                          if (trailingWidget != null) trailingWidget!,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Icon circle — centered, straddles the wave bottom
          Positioned(
            top: h - _iconDiameter * 0.5,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: _iconDiameter,
                height: _iconDiameter,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2038F5).withOpacity(0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: icon,
              ).animate().scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                    delay: 200.ms,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width * 0.20,
      size.height,
      size.width * 0.50,
      size.height - 24,
    );
    path.quadraticBezierTo(
      size.width * 0.80,
      size.height - 50,
      size.width,
      size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}
