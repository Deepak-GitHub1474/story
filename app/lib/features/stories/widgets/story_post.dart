import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../core/utils/time_ago.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';

class StoryPost extends StatelessWidget {
  const StoryPost({
    super.key,
    required this.story,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onAuthorTap,
    this.onShare,
    this.showVisibility = false,
  });

  final Story story;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onShare;
  final bool showVisibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
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
                GestureDetector(
                  onTap: onAuthorTap,
                  child: AppAvatar(seed: story.author.avatarSeed, size: 34),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.author.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppTypeScale.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${timeAgo(story.publishedAt ?? story.createdAt)} · ${story.readingMinutes} min',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: AppTypeScale.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showVisibility) VisibilityBadge(visibility: story.visibility),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (story.title != null && story.title!.isNotEmpty) ...[
              Text(
                story.title!,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.heading,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              story.excerpt,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.reading,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                LikeIcon(isLiked: story.isLiked, onTap: onLike),
                const SizedBox(width: AppSpacing.lg),
                InkResponse(
                  onTap: onComment ?? onTap,
                  radius: 22,
                  child: Icon(
                    Icons.mode_comment_outlined,
                    size: AppSizes.iconMd,
                    color: colors.textPrimary,
                  ),
                ),
                if (onShare != null) ...[
                  const SizedBox(width: AppSpacing.lg),
                  InkResponse(
                    onTap: onShare,
                    radius: 22,
                    child: Icon(
                      Icons.ios_share,
                      size: AppSizes.iconMd,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${story.readingMinutes} min',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ],
            ),
            if (story.likes > 0 || story.comments > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                  if (story.likes > 0)
                    '${story.likes} ${story.likes == 1 ? 'like' : 'likes'}',
                  if (story.comments > 0)
                    '${story.comments} ${story.comments == 1 ? 'comment' : 'comments'}',
                ].join('  ·  '),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LikeIcon extends StatefulWidget {
  const LikeIcon({super.key, required this.isLiked, this.onTap, this.size});

  final bool isLiked;
  final VoidCallback? onTap;
  final double? size;

  @override
  State<LikeIcon> createState() => _LikeIconState();
}

class _LikeIconState extends State<LikeIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.92), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 30),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isLiked) _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkResponse(
      onTap: widget.onTap == null ? null : _handleTap,
      radius: 22,
      child: ScaleTransition(
        scale: _scale,
        child: Icon(
          widget.isLiked ? Icons.favorite : Icons.favorite_border,
          size: widget.size ?? AppSizes.iconMd,
          color: widget.isLiked ? colors.danger : colors.textPrimary,
        ),
      ),
    );
  }
}

class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.visibility});

  final String visibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (visibility) {
      'public' => ('Public', colors.success),
      'private' => ('Private', colors.textSecondary),
      'scheduled' => ('Scheduled', colors.accent),
      _ => ('Draft', colors.accent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
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
