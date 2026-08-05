import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../stories/providers/story_providers.dart';
import '../../stories/widgets/story_list_view.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _filter;

  static const _tabs = [
    (null, 'All'),
    ('public', 'Public'),
    ('private', 'Private'),
    ('draft', 'Drafts'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;
    final stories = ref.watch(myStoriesProvider);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '@${user.username}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.heading,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: colors.textMuted),
                  onPressed: () => context.push(Routes.editProfile),
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: colors.textMuted),
                  onPressed: () => context.go(Routes.settings),
                ),
              ],
            ),
          ),
          Expanded(
            child: StoryListView(
              state: stories,
              showVisibility: true,
              onRefresh: () => ref.read(myStoriesProvider.notifier).refresh(),
              onLoadMore: () => ref.read(myStoriesProvider.notifier).loadMore(),
              onOpen: (story) => story.isDraft
                  ? context.push('${Routes.compose}?id=${story.storyId}')
                  : context.push('${Routes.story}/${story.storyId}'),
              emptyTitle: _filter == 'draft' ? 'No drafts' : 'No stories yet',
              emptyBody: 'Everything you write lands here, drafts included.',
              header: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onLongPress: () async {
                          final result = await ref
                              .read(profileRepositoryProvider)
                              .regenerateAvatar();
                          if (!context.mounted) return;
                          if (result.isSuccess) {
                            await ref.read(authProvider.notifier).refreshUser();
                            if (!context.mounted) return;
                            AppToast.show(context, 'New avatar.');
                          }
                        },
                        child: AppAvatar(seed: user.avatarSeed, size: 72),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Stat(
                              value: '${user.counts['stories'] ?? 0}',
                              label: 'Stories',
                            ),
                            _Stat(
                              value: '${user.counts['followers'] ?? 0}',
                              label: 'Readers',
                            ),
                            _Stat(
                              value: '${user.counts['connections'] ?? 0}',
                              label: 'Following',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      user.displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.body,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        user.bio!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.label,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (user.interests.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final slug in user.interests.take(6))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceRaised,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                slug.replaceAll('-', ' '),
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: AppTypeScale.caption,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final tab in _tabs)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: _FilterChip(
                              label: tab.$2,
                              isActive: _filter == tab.$1,
                              onTap: () {
                                setState(() => _filter = tab.$1);
                                ref.read(myStoriesProvider.notifier).filter(tab.$1);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: isActive ? colors.accent : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: isActive ? colors.accent : colors.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? colors.accentText : colors.textSecondary,
              fontSize: AppTypeScale.label,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
