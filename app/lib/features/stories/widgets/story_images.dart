import 'package:flutter/material.dart';

import '../../../core/api/endpoints.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

String storyImageUrl(String path) =>
    path.startsWith('http') ? path : '${Endpoints.baseUrl.replaceAll('/v1', '')}$path';

class StoryImages extends StatelessWidget {
  const StoryImages({
    super.key,
    required this.images,
    this.height = 220,
    this.onRemove,
  });

  final List<String> images;
  final double height;
  final void Function(String path)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final path = images[index];

          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Stack(
              children: [
                Image.network(
                  storyImageUrl(path),
                  height: height,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: height,
                    height: height,
                    color: colors.surfaceRaised,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.textMuted,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          width: height,
                          height: height,
                          color: colors.surfaceRaised,
                        ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: InkWell(
                      onTap: () => onRemove!(path),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.bg.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: AppSizes.iconSm,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
