import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../core/utils/time_ago.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import 'shared_story_card.dart';
import 'story_images.dart';

class StoryPost extends StatefulWidget {
  const StoryPost({
    super.key,
    required this.story,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onAuthorTap,
    this.onShare,
    this.onSharedTap,
    this.onLongPress,
    this.showVisibility = false,
  });

  final Story story;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onShare;
  final VoidCallback? onSharedTap;
  final VoidCallback? onLongPress;
  final bool showVisibility;

  @override
  State<StoryPost> createState() => _StoryPostState();
}

class _StoryPostState extends State<StoryPost> {
  bool _isExpanded = false;

  static const _collapsedLines = 3;

  Story get story => widget.story;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasImages = story.images.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onAuthorTap,
                child: AppAvatar(
                  seed: story.author.avatarSeed,
                  size: 34,
                  displayName: story.author.displayName,
                  username: story.author.username,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onAuthorTap,
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
                    Text(
                      story.shared != null
                          ? 'Shared ${story.shared!.author.displayName}\'s story'
                          : '${timeAgo(story.publishedAt ?? story.createdAt)} · ${story.readingMinutes} min',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showVisibility)
                VisibilityBadge(visibility: story.visibility),
              if (widget.onLongPress != null)
                IconButton(
                  icon: Icon(Icons.more_horiz, color: colors.textMuted),
                  onPressed: widget.onLongPress,
                ),
            ],
          ),
        ),

        if (hasImages) StoryImages(
                        images: story.images,
                        ratio: story.imageRatio,
                        fit: story.imageFit,
                      ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            hasImages ? AppSpacing.md : 0,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LikeIcon(isLiked: story.isLiked, onTap: widget.onLike),
                  const SizedBox(width: AppSpacing.lg),
                  InkResponse(
                    onTap: widget.onComment ?? widget.onTap,
                    radius: 22,
                    child: Icon(
                      Icons.mode_comment_outlined,
                      size: AppSizes.iconMd,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (widget.onShare != null) ...[
                    const SizedBox(width: AppSpacing.lg),
                    InkResponse(
                      onTap: widget.onShare,
                      radius: 22,
                      child: Icon(
                        Icons.ios_share,
                        size: AppSizes.iconMd,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
              if (story.likes > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${story.likes} ${story.likes == 1 ? 'like' : 'likes'}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _Caption(
                story: story,
                isExpanded: _isExpanded,
                collapsedLines: _collapsedLines,
                onToggle: () => setState(() => _isExpanded = !_isExpanded),
                onOpen: widget.onTap,
              ),
              if (story.shared != null) ...[
                const SizedBox(height: AppSpacing.md),
                SharedStoryCard(shared: story.shared!, onTap: widget.onSharedTap),
              ],
              if (story.comments > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: widget.onComment ?? widget.onTap,
                  child: Text(
                    story.comments == 1
                        ? 'View 1 comment'
                        : 'View all ${story.comments} comments',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.label,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                timeAgo(story.publishedAt ?? story.createdAt),
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: AppTypeScale.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.story,
    required this.isExpanded,
    required this.collapsedLines,
    required this.onToggle,
    this.onOpen,
  });

  final Story story;
  final bool isExpanded;
  final int collapsedLines;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = story.title;
    final body = story.excerpt;

    if ((title == null || title.isEmpty) && body.isEmpty) {
      return const SizedBox.shrink();
    }

    final text = TextSpan(
      children: [
        TextSpan(
          text: story.author.displayName,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        const TextSpan(text: '  '),
        if (title != null && title.isNotEmpty)
          TextSpan(
            text: '$title\n',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.label,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        TextSpan(
          text: body,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.label,
            height: 1.5,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: text,
          maxLines: collapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: overflows ? onToggle : onOpen,
              child: RichText(
                text: text,
                maxLines: isExpanded ? null : collapsedLines,
                overflow: isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isExpanded ? 'less' : 'more',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
