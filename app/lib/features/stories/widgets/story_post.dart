import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_avatar.dart';
import '../../../components/double_tap_like.dart';
import '../../../components/expandable_text.dart';
import '../../../components/story_glyphs.dart';
import '../../../components/story_text.dart';
import '../../../core/utils/time_ago.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import 'liked_by_row.dart';
import 'likes_sheet.dart';
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
                onTap: story.author.isReachable ? widget.onAuthorTap : null,
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
                      onTap: story.author.isReachable ? widget.onAuthorTap : null,
                      child: Text(
                        story.author.handle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppTypeScale.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      story.shared != null
                          ? 'Shared ${story.shared!.author.handle}\'s story'
                          : '${timeAgoLong(story.publishedAt ?? story.createdAt)}'
                                '${story.wasEdited ? ' · Edited' : ''}',
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

        if (hasImages)
          DoubleTapLike(
            isLiked: story.isLiked,
            onLike: widget.onLike,
            onTap: widget.onTap,
            child: StoryImages(
              images: story.images,
              ratio: story.imageRatio,
              fit: story.imageFit,
            ),
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
                  if (story.likes > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _Count(
                      value: story.likes,
                      onTap: () => showLikesSheet(
                        context: context,
                        storyId: story.storyId,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.lg),
                  InkResponse(
                    onTap: widget.onComment ?? widget.onTap,
                    radius: 22,
                    child: CommentGlyph(
                      size: AppSizes.iconAction,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (story.comments > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _Count(
                      value: story.comments,
                      onTap: widget.onComment ?? widget.onTap,
                    ),
                  ],
                  if (widget.onShare != null) ...[
                    const SizedBox(width: AppSpacing.lg),
                    InkResponse(
                      onTap: widget.onShare,
                      radius: 22,
                      child: ShareGlyph(
                        size: AppSizes.iconAction,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
              if (story.likedBy.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                LikedByRow(
                  people: story.likedBy,
                  likes: story.likes,
                  onTap: () =>
                      showLikesSheet(context: context, storyId: story.storyId),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _Caption(
                story: story,
                collapsedLines: _collapsedLines,
                onOpen: widget.onTap,
              ),
              if (story.shared != null) ...[
                const SizedBox(height: AppSpacing.md),
                SharedStoryCard(
                  shared: story.shared!,
                  onTap: widget.onSharedTap,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

class _Caption extends ConsumerStatefulWidget {
  const _Caption({
    required this.story,
    required this.collapsedLines,
    this.onOpen,
  });

  final Story story;
  final int collapsedLines;
  final VoidCallback? onOpen;

  @override
  ConsumerState<_Caption> createState() => _CaptionState();
}

class _CaptionState extends ConsumerState<_Caption> {
  String? _whole;

  Story get story => widget.story;

  bool get _isTrimmed => story.excerpt.endsWith('…');

  Future<TextSpan?> _readTheRest() async {
    if (_whole != null) return _span(_whole!, context.colors);
    if (!_isTrimmed) return null;

    final inHand = story.body;
    if (inHand != null && inHand.isNotEmpty) {
      setState(() => _whole = plainStoryText(inHand));
      return _span(_whole!, context.colors);
    }

    try {
      final detail = await ref.read(storyDetailProvider(story.storyId).future);
      if (!mounted) return null;
      final body = detail.body;
      if (body != null && body.isNotEmpty) {
        setState(() => _whole = plainStoryText(body));
        return _span(_whole!, context.colors);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  TextSpan _span(String body, AppColors colors) => TextSpan(
    children: [
      TextSpan(
        text: story.author.handle,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: AppTypeScale.label,
          fontWeight: FontWeight.w500,
        ),
      ),
      const TextSpan(text: '  '),
      if (story.title != null && story.title!.isNotEmpty)
        TextSpan(
          text: '${story.title}\n',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = story.title;

    if ((title == null || title.isEmpty) && story.excerpt.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpandableText(
      collapsedLines: widget.collapsedLines,
      onTapWhenShort: widget.onOpen,
      onExpand: _isTrimmed ? _readTheRest : null,
      maxExpandedHeight: MediaQuery.sizeOf(context).height * 0.5,
      onTooLong: (_) => widget.onOpen?.call(),
      text: _span(story.excerpt, colors),
      expandedText: _whole == null ? null : _span(_whole!, colors),
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

class _LikeIconState extends State<LikeIcon>
    with SingleTickerProviderStateMixin {
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
          size: widget.size ?? AppSizes.iconAction,
          color: widget.isLiked ? colors.like : colors.textPrimary,
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
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, this.onTap});

  final int value;
  final VoidCallback? onTap;

  String get _short {
    if (value < 1000) return '$value';
    if (value < 100000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}k';
    }
    return '${(value / 100000).toStringAsFixed(1)}L';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Text(
        _short,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: AppTypeScale.label,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
