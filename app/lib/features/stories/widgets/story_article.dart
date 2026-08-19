import 'package:flutter/material.dart';

import '../../../components/double_tap_like.dart';
import '../../../components/story_text.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import 'shared_story_card.dart';
import 'story_images.dart';

/// A story as it is read: the picture, the title, the words, and whatever
/// it was written on top of.
///
/// The card in the feed shows the picture first, so this does too — tapping
/// a card must not make the picture jump to the bottom of the screen.
class StoryArticle extends StatelessWidget {
  const StoryArticle({
    super.key,
    required this.story,
    required this.bodySize,
    this.onLike,
    this.onSharedTap,
  });

  final Story story;
  final double bodySize;
  final VoidCallback? onLike;
  final VoidCallback? onSharedTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = story.title;
    final body = story.body ?? story.excerpt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (story.images.isNotEmpty) ...[
          DoubleTapLike(
            isLiked: story.isLiked,
            onLike: onLike,
            child: StoryImages(
              images: story.images,
              ratio: story.imageRatio,
              fit: story.imageFit,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (title != null && title.isNotEmpty) ...[
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (body.isNotEmpty) StoryText(text: body, fontSize: bodySize),
        if (story.shared != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SharedStoryCard(shared: story.shared!, onTap: onSharedTap),
        ],
      ],
    );
  }
}
