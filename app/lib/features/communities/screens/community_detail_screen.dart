import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_toast.dart';
import '../../../components/skeleton.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../stories/models/story_models.dart';
import '../../stories/providers/story_providers.dart';
import '../../stories/widgets/story_post.dart';
import '../models/community_models.dart';
import '../providers/community_providers.dart';

final _communityDetailProvider =
    FutureProvider.family<Community, String>((ref, slug) async {
      final result = await ref.watch(communityRepositoryProvider).detail(slug);
      final community = result.valueOrNull;
      if (community == null) throw Exception('Not found');
      return community;
    });

final _communityStoriesProvider =
    FutureProvider.family<List<Story>, String>((ref, slug) async {
      final result = await ref.watch(communityRepositoryProvider).stories(slug);
      return result.valueOrNull?.items ?? const [];
    });

class CommunityDetailScreen extends ConsumerWidget {
  const CommunityDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final community = ref.watch(_communityDetailProvider(slug));
    final stories = ref.watch(_communityStoriesProvider(slug));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: community.when(
        loading: () => const SkeletonList(count: 4),
        error: (error, _) => Center(
          child: Text(
            'This community is not available.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        data: (data) => RefreshIndicator(
          color: colors.accent,
          backgroundColor: colors.surface,
          onRefresh: () async {
            ref.invalidate(_communityDetailProvider(slug));
            ref.invalidate(_communityStoriesProvider(slug));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      data.description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.body,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${data.members} ${data.members == 1 ? 'member' : 'members'}  ·  ${data.stories} stories',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: data.isMember ? Colors.transparent : colors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          onTap: () async {
                            await ref
                                .read(communityRepositoryProvider)
                                .setMembership(slug, join: !data.isMember);
                            ref.invalidate(_communityDetailProvider(slug));
                            ref.invalidate(myCommunitiesProvider);
                            ref.invalidate(communityBrowseProvider);
                          },
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: data.isMember ? colors.border : colors.accent,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              data.isMember ? 'Leave community' : 'Join community',
                              style: TextStyle(
                                color: data.isMember
                                    ? colors.textSecondary
                                    : colors.accentText,
                                fontSize: AppTypeScale.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              stories.when(
                loading: () => const SkeletonList(count: 3),
                error: (error, _) => const SizedBox.shrink(),
                data: (items) => items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 40,
                              color: colors.textMuted,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No stories here yet',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              data.isMember
                                  ? 'Write the first one.'
                                  : 'Join to write the first one.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: AppTypeScale.label,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (final story in items) ...[
                            _InteractiveStory(
                              story: story,
                              onChanged: () =>
                                  ref.invalidate(_communityStoriesProvider(slug)),
                            ),
                            Divider(height: 1, color: colors.border),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}


class _InteractiveStory extends ConsumerStatefulWidget {
  const _InteractiveStory({required this.story, required this.onChanged});

  final Story story;
  final VoidCallback onChanged;

  @override
  ConsumerState<_InteractiveStory> createState() => _InteractiveStoryState();
}

class _InteractiveStoryState extends ConsumerState<_InteractiveStory> {
  Story? _override;

  Story get _story => _override ?? widget.story;

  Future<void> _toggleLike() async {
    final current = _story;
    final next = !current.isLiked;
    setState(() {
      _override = current.copyWith(
        isLiked: next,
        likes: current.likes + (next ? 1 : -1),
      );
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .setLike(current.storyId, liked: next);

    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _override = _override!.copyWith(likes: result.valueOrNull));
    } else {
      setState(() => _override = current);
    }
  }

  Future<void> _share() async {
    final result = await ref.read(storyRepositoryProvider).share(_story.storyId);
    if (!mounted) return;

    final url = result.valueOrNull;
    if (url == null) {
      AppToast.show(context, result.failureOrNull!.message, kind: AppToastKind.error);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppToast.show(context, 'Link copied.', kind: AppToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    return StoryPost(
      story: _story,
      onTap: () async {
        await context.push('${Routes.story}/${_story.storyId}');
        widget.onChanged();
      },
      onLike: _toggleLike,
      onShare: _story.isPublic ? _share : null,
      onAuthorTap: () => context.push('${Routes.user}/${_story.author.username}'),
    );
  }
}
