import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_sheet.dart';
import '../../../components/app_toast.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routing/routes.dart';
import '../../../components/skeleton.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';

import '../../stories/models/story_models.dart';
import '../../stories/providers/story_providers.dart';
import '../../stories/widgets/comments_sheet.dart';
import '../../stories/widgets/story_list_view.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (null, 'All'),
    ('public', 'Public'),
    ('private', 'Private'),
    ('draft', 'Drafts'),
  ];

  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
  )..addListener(_onTabChanged);

  String? _filter;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final next = _tabs[_tabController.index].$1;
    if (next == _filter) return;
    setState(() => _filter = next);
    ref.read(myStoriesProvider.notifier).filter(next);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 240) return;

    final next = velocity < 0
        ? _tabController.index + 1
        : _tabController.index - 1;
    if (next < 0 || next >= _tabs.length) return;

    HapticFeedback.selectionClick();
    _tabController.animateTo(next);
  }

  Future<void> _openStoryActions(Story story) async {
    final colors = context.colors;

    final action = await showAppSheet<SwipeAction>(
      context: context,
      title: story.title?.isNotEmpty == true ? story.title! : 'This story',
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (story.isDraft)
              ListTile(
                leading: Icon(Icons.publish_rounded, color: colors.textPrimary),
                title: const Text('Publish it'),
                onTap: () => Navigator.of(sheetContext).pop(SwipeAction.publish),
              )
            else
              ListTile(
                leading: Icon(Icons.archive_outlined, color: colors.textPrimary),
                title: const Text('Move back to drafts'),
                onTap: () => Navigator.of(sheetContext).pop(SwipeAction.archive),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.danger),
              title: Text('Delete', style: TextStyle(color: colors.danger)),
              onTap: () => Navigator.of(sheetContext).pop(SwipeAction.delete),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (action != null && mounted) await _act(story, action);
  }

  Future<bool> _act(Story story, SwipeAction action) async {
    final repository = ref.read(storyRepositoryProvider);
    final notifier = ref.read(myStoriesProvider.notifier);

    switch (action) {
      case SwipeAction.delete:
        final confirmed = await confirmAction(
          context,
          title: 'Delete this story?',
          body: 'This cannot be undone.',
          confirmLabel: 'Delete',
          cancelLabel: 'Keep',
        );
        if (!confirmed) return false;
        await repository.remove(story.storyId);
        notifier.remove(story.storyId);
        await ref.read(authProvider.notifier).refreshUser();
        if (mounted) AppToast.show(context, 'Story deleted.');
        return false;

      case SwipeAction.archive:
        await repository.unpublish(story.storyId);
        await notifier.refresh();
        await ref.read(authProvider.notifier).refreshUser();
        if (mounted) AppToast.show(context, 'Moved back to drafts.');
        return false;

      case SwipeAction.publish:
        await repository.publish(story.storyId, visibility: 'public');
        await notifier.refresh();
        await ref.read(authProvider.notifier).refreshUser();
        if (mounted) {
          AppToast.show(context, 'Your story is live.', kind: AppToastKind.success);
        }
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;
    final stories = ref.watch(myStoriesProvider);

    if (user == null) {
      return const SkeletonList(count: 4);
    }

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onTabSwipe,
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: colors.textMuted),
                  onPressed: () => context.push(Routes.editProfile),
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: colors.textMuted),
                  onPressed: () => context.push(Routes.settings),
                ),
              ],
            ),
          ),
          Expanded(
            child: StoryListView(
              state: stories,
              showVisibility: true,
              onLongPress: _openStoryActions,
              onComment: (story) => showCommentsSheet(
                context: context,
                storyId: story.storyId,
              ),
              onRefresh: () => ref.read(myStoriesProvider.notifier).refresh(),
              onLoadMore: () => ref.read(myStoriesProvider.notifier).loadMore(),
              onOpenShared: (storyId) => context.push('${Routes.story}/$storyId'),
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
                        onTap: () => context.push(Routes.avatar),
                        child: AppAvatar(
                          seed: user.avatarSeed,
                          size: 72,
                          displayName: user.displayName,
                          username: user.username,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.body,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _Stat(
                                  value: '${user.counts['stories'] ?? 0}',
                                  label: 'Stories',
                                ),
                                _Stat(
                                  value: '${user.counts['followers'] ?? 0}',
                                  label: 'Followers',
                                  onTap: () => context.push(Routes.followers),
                                ),
                                _Stat(
                                  value: '${user.counts['connections'] ?? 0}',
                                  label: 'Following',
                                  onTap: () => context.push(Routes.following),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  const SizedBox(height: AppSpacing.lg),
                  TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    labelColor: colors.textPrimary,
                    unselectedLabelColor: colors.textMuted,
                    indicatorColor: colors.accent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w500,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: [for (final tab in _tabs) Tab(text: tab.$2)],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTypeScale.heading,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(color: colors.textMuted, fontSize: AppTypeScale.caption),
        ),
      ],
      ),
    );
  }
}
