import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/skeleton.dart';
import '../../../routing/routes.dart';
import '../../settings/providers/theme_provider.dart';
import '../../../components/app_close_button.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../stories/widgets/story_post.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _remembered = '';

  void _rememberSettledQuery(SearchState state) {
    final query = state.query.trim();
    if (state.isLoading || query.isEmpty || query == _remembered) return;
    if (state.results.users.isEmpty) return;

    _remembered = query;
    ref.read(prefsStoreProvider).rememberSearch(query);
  }

  Future<void> _pick(String username) async {
    _controller.text = username;
    ref.read(searchProvider.notifier).query(username);
  }

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(searchProvider);
    _rememberSettledQuery(state);
    final results = state.results;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: colors.textPrimary, fontSize: AppTypeScale.body),
          onChanged: (value) => ref.read(searchProvider.notifier).query(value),
          decoration: InputDecoration(
            hintText: 'People, communities, stories',
            hintStyle: TextStyle(color: colors.textMuted),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            AppCloseButton(
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                ref.read(searchProvider.notifier).query('');
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (state.query.isEmpty) return _RecentSearches(onPick: _pick);
            if (state.isLoading) return const SkeletonList(count: 4);
            if (results.isEmpty) {
              return Center(
                child: Text(
                  'Nothing matched “${state.query}”.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              );
            }

            return ListView(
              children: [
                if (results.users.isNotEmpty) ...[
                  _SectionHeader(label: 'People'),
                  for (final user in results.users)
                    ListTile(
                      leading: AppAvatar(
                        seed: user.avatarSeed,
                        size: 40,
                        displayName: user.displayName,
                        username: user.username,
                      ),
                      title: Text(
                        user.displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: TextStyle(color: colors.textMuted),
                      ),
                      onTap: () async {
                        await ref
                            .read(prefsStoreProvider)
                            .rememberSearch(user.username);
                        if (context.mounted) {
                          await context.push('${Routes.user}/${user.username}');
                        }
                      },
                    ),
                ],
                if (results.communities.isNotEmpty) ...[
                  _SectionHeader(label: 'Communities'),
                  for (final community in results.communities)
                    ListTile(
                      leading: Icon(Icons.groups_outlined, color: colors.accent),
                      title: Text(
                        community.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${community.members} members',
                        style: TextStyle(color: colors.textMuted),
                      ),
                      onTap: () =>
                          context.push('${Routes.community}/${community.slug}'),
                    ),
                ],
                if (results.stories.isNotEmpty) ...[
                  _SectionHeader(label: 'Stories'),
                  for (final story in results.stories) ...[
                    StoryPost(
                      story: story,
                      onTap: () => context.push('${Routes.story}/${story.storyId}'),
                      onAuthorTap: () =>
                          context.push('${Routes.user}/${story.author.username}'),
                    ),
                    Divider(height: 1, color: colors.border),
                  ],
                ],
                const SizedBox(height: AppSpacing.xxxl),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.textMuted,
          fontSize: AppTypeScale.caption,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 44, color: colors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Find your people',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Search accounts, communities, and public stories. '
              'Private and draft stories never appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.body,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _RecentSearches extends ConsumerStatefulWidget {
  const _RecentSearches({required this.onPick});

  final Future<void> Function(String username) onPick;

  @override
  ConsumerState<_RecentSearches> createState() => _RecentSearchesState();
}

class _RecentSearchesState extends ConsumerState<_RecentSearches> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final recent = ref.read(prefsStoreProvider).recentSearches;

    if (recent.isEmpty) return _Hint();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'RECENT',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: AppTypeScale.caption,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  await ref.read(prefsStoreProvider).clearSearches();
                  if (mounted) setState(() {});
                },
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: AppTypeScale.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final username in recent)
          ListTile(
            leading: Icon(Icons.history, color: colors.textMuted),
            title: Text(
              '@$username',
              style: TextStyle(color: colors.textPrimary),
            ),
            trailing: AppCloseButton(
              size: AppCloseSize.small,
              tooltip: 'Forget this search',
              onPressed: () async {
                await ref.read(prefsStoreProvider).forgetSearch(username);
                if (mounted) setState(() {});
              },
            ),
            onTap: () => widget.onPick(username),
          ),
      ],
    );
  }
}
