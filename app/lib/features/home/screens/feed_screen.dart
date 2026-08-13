import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../stories/models/story_models.dart';
import '../../stories/providers/story_providers.dart';
import '../../stories/widgets/comments_sheet.dart';
import '../../stories/widgets/share_sheet.dart';
import '../../stories/widgets/story_list_view.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Future<void> _share(BuildContext context, WidgetRef ref, Story story) async {
    final posted = await showShareSheet(context: context, ref: ref, story: story);
    if (posted) await ref.read(feedProvider.notifier).refresh();
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
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  'STORY',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.heading,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search, color: colors.textPrimary),
                  onPressed: () => context.push(Routes.search),
                ),
                IconButton(
                  icon: Icon(Icons.groups_outlined, color: colors.textPrimary),
                  onPressed: () => context.push(Routes.communities),
                ),
              ],
            ),
          ),
          Expanded(
            child: StoryListView(
              state: state,
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              onLoadMore: () => ref.read(feedProvider.notifier).loadMore(),
              onOpen: (story) => context.push('${Routes.story}/${story.storyId}'),
              onAuthorTap: (story) => context.push(
                '${Routes.user}/${story.author.username}',
              ),
              onLike: (story) => toggleStoryLike(ref, story),
              onComment: (story) => showCommentsSheet(
                context: context,
                storyId: story.storyId,
              ),
              onShare: (story) => _share(context, ref, story),
              onOpenShared: (storyId) => context.push('${Routes.story}/$storyId'),
              endLabel: 'You are all caught up',
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
