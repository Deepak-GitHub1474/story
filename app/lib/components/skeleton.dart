import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1 - 2 * _controller.value, 0),
          end: Alignment(1 - 2 * _controller.value, 0),
          colors: [
            colors.surfaceRaised,
            colors.border,
            colors.surfaceRaised,
          ],
          stops: const [0.35, 0.5, 0.65],
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class StorySkeleton extends StatelessWidget {
  const StorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(width: 34, height: 34, radius: AppRadius.pill),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 120, height: 12),
                    const SizedBox(height: AppSpacing.xs),
                    const SkeletonBox(width: 74, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SkeletonBox(width: 220, height: 16),
            const SizedBox(height: AppSpacing.md),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(width: double.infinity, height: 12),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(width: 200, height: 12),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: const [
                SkeletonBox(width: 22, height: 22, radius: AppRadius.pill),
                SizedBox(width: AppSpacing.lg),
                SkeletonBox(width: 22, height: 22, radius: AppRadius.pill),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (context, index) =>
          Divider(height: 1, thickness: 1, color: colors.border),
      itemBuilder: (context, index) => const StorySkeleton(),
    );
  }
}

class EndOfFeed extends StatelessWidget {
  const EndOfFeed({super.key, this.label = 'You are all caught up'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Container(width: 32, height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ),
    );
  }
}
