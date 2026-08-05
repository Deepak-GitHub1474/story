import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../stories/models/story_models.dart';
import '../../stories/providers/story_providers.dart';
import '../../stories/widgets/story_list_view.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Future<void> _like(WidgetRef ref, Story story) async {
    final next = !story.isLiked;
    final notifier = ref.read(feedProvider.notifier);
    notifier.replace(
      story.copyWith(isLiked: next, likes: story.likes + (next ? 1 : -1)),
    );

    final result = await ref
        .read(storyRepositoryProvider)
        .setLike(story.storyId, liked: next);
    if (result.isSuccess) {
      notifier.replace(story.copyWith(isLiked: next, likes: result.valueOrNull));
    } else {
      notifier.replace(story);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(feedProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  'STORY',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.heading,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: StoryListView(
              state: state,
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              onLoadMore: () => ref.read(feedProvider.notifier).loadMore(),
              onOpen: (story) => context.push('${Routes.story}/${story.storyId}'),
              onLike: (story) => _like(ref, story),
              emptyTitle: 'Nothing here yet',
              emptyBody:
                  'Tap the + to write the first one. Nobody will know it was you.',
            ),
          ),
        ],
      ),
    );
  }
}
