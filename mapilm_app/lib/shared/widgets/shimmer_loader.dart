import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ConversationShimmer extends StatelessWidget {
  const ConversationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, __) => const _ConversationTileShimmer(),
    );
  }
}

class _ConversationTileShimmer extends StatelessWidget {
  const _ConversationTileShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ShimmerBox(width: 52, height: 52, borderRadius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 14, borderRadius: 7),
                const SizedBox(height: 6),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShimmerBox(width: 36, height: 10, borderRadius: 5),
              const SizedBox(height: 6),
              ShimmerBox(width: 20, height: 20, borderRadius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class MessageShimmer extends StatelessWidget {
  const MessageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      reverse: true,
      itemBuilder: (_, i) => _MessageBubbleShimmer(isOutgoing: i.isEven),
    );
  }
}

class _MessageBubbleShimmer extends StatelessWidget {
  const _MessageBubbleShimmer({required this.isOutgoing});
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment:
            isOutgoing ? Alignment.centerLeft : Alignment.centerRight,
        child: ShimmerBox(
          width: 180 + (isOutgoing ? 40.0 : 0.0),
          height: 48,
          borderRadius: 18,
        ),
      ),
    );
  }
}
