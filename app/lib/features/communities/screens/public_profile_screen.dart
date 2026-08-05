import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
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

final _userStoriesProvider =
    FutureProvider.family<List<Story>, String>((ref, username) async {
      final result = await ref.watch(storyRepositoryProvider).byUser(username);
      return result.valueOrNull?.items ?? const [];
    });

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  PublicProfile? _override;

  Future<void> _toggleFollow(PublicProfile profile) async {
    final next = !profile.isFollowing;
    setState(() {
      _override = profile.copyWith(
        isFollowing: next,
        followers: profile.followers + (next ? 1 : -1),
      );
    });

    final result = await ref
        .read(communityRepositoryProvider)
        .setFollow(profile.username, follow: next);

    if (!mounted) return;
    if (result.failureOrNull != null) {
      setState(() => _override = profile);
      AppToast.show(context, result.failureOrNull!.message, kind: AppToastKind.error);
    } else {
      ref.invalidate(feedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final asyncProfile = ref.watch(publicProfileProvider(widget.username));
    final stories = ref.watch(_userStoriesProvider(widget.username));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text('@${widget.username}'),
      ),
      body: asyncProfile.when(
        loading: () => const SkeletonList(count: 4),
        error: (error, _) => Center(
          child: Text(
            'This account is not available.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        data: (fetched) {
          final profile = _override ?? fetched;

          return RefreshIndicator(
            color: colors.accent,
            backgroundColor: colors.surface,
            onRefresh: () async {
              ref.invalidate(publicProfileProvider(widget.username));
              ref.invalidate(_userStoriesProvider(widget.username));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(seed: profile.avatarSeed, size: 72),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat(value: '${profile.stories}', label: 'Stories'),
                                _Stat(value: '${profile.followers}', label: 'Readers'),
                                _Stat(value: '${profile.following}', label: 'Following'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        profile.displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppTypeScale.body,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          profile.bio!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: AppTypeScale.label,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (!profile.isMe) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: profile.isFollowing
                                ? Colors.transparent
                                : colors.accent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InkWell(
                              onTap: () => _toggleFollow(profile),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: profile.isFollowing
                                        ? colors.border
                                        : colors.accent,
                                  ),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Text(
                                  profile.isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: profile.isFollowing
                                        ? colors.textPrimary
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
                          child: Center(
                            child: Text(
                              'Nothing public yet.',
                              style: TextStyle(color: colors.textMuted),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final story in items) ...[
                              _InteractiveStory(
                                story: story,
                                onChanged: () => ref.invalidate(
                                  _userStoriesProvider(widget.username),
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTypeScale.heading,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(color: colors.textMuted, fontSize: AppTypeScale.caption),
        ),
      ],
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
