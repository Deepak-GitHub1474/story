import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../core/utils/time_ago.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    this.onTap,
    this.onLike,
    this.showVisibility = false,
  });

  final Story story;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool showVisibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(seed: story.author.avatarSeed, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      story.author.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.label,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showVisibility)
                    _VisibilityBadge(visibility: story.visibility)
                  else
                    Text(
                      timeAgo(story.publishedAt ?? story.createdAt),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (story.title != null && story.title!.isNotEmpty) ...[
                Text(
                  story.title!,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.heading,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                story.excerpt,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.body,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _LikeButton(
                    isLiked: story.isLiked,
                    count: story.likes,
                    onTap: onLike,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Icon(
                    Icons.mode_comment_outlined,
                    size: AppSizes.iconSm,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${story.comments}',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${story.readingMinutes} min read',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.isLiked, required this.count, this.onTap});

  final bool isLiked;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isLiked ? colors.danger : colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            AnimatedScale(
              scale: isLiked ? 1.18 : 1,
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: AppSizes.iconSm,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: AppTypeScale.caption),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});

  final String visibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (visibility) {
      'public' => ('Public', colors.success),
      'private' => ('Private', colors.textSecondary),
      _ => ('Draft', colors.accent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppTypeScale.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
