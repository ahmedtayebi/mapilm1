import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.backgroundColor,
  });

  final String? imageUrl;
  final String? name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildAvatar(),
        if (showOnlineIndicator)
          Positioned(
            bottom: 0,
            right: 0,
            child: _OnlineIndicator(isOnline: isOnline, size: radius * 0.4),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (_, provider) => CircleAvatar(
          radius: radius,
          backgroundImage: provider,
        ),
        placeholder: (_, __) => _shimmerAvatar(),
        errorWidget: (_, __, ___) => _fallbackAvatar(),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final initials = _getInitials();
    final bg = backgroundColor ?? _colorFromName();
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _shimmerAvatar() {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: CircleAvatar(radius: radius, backgroundColor: AppColors.grey200),
    );
  }

  String _getInitials() {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _colorFromName() {
    if (name == null || name!.isEmpty) return AppColors.grey400;
    const colors = [
      Color(0xFF2038F5), Color(0xFF7C3AED), Color(0xFFDB2777),
      Color(0xFFDC2626), Color(0xFFD97706), Color(0xFF059669),
      Color(0xFF0891B2), Color(0xFF4F46E5),
    ];
    final index = name!.codeUnitAt(0) % colors.length;
    return colors[index];
  }
}

class _OnlineIndicator extends StatelessWidget {
  const _OnlineIndicator({required this.isOnline, required this.size});
  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? AppColors.online : AppColors.offline,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
