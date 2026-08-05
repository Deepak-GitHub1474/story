import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import 'story_post.dart';

enum SwipeAction { delete, archive, publish }

class StoryListView extends StatefulWidget {
  const StoryListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    this.onLike,
    this.onSwipe,
    this.emptyTitle = 'Nothing here yet',
    this.emptyBody = '',
    this.showVisibility = false,
    this.header,
  });

  final StoryListState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final void Function(Story story) onOpen;
  final void Function(Story story)? onLike;
  final Future<bool> Function(Story story, SwipeAction action)? onSwipe;
  final String emptyTitle;
  final String emptyBody;
  final bool showVisibility;
  final Widget? header;

  @override
  State<StoryListView> createState() => _StoryListViewState();
}

class _StoryListViewState extends State<StoryListView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final position = _controller.position;
      if (position.pixels > position.maxScrollExtent - 400) widget.onLoadMore();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = widget.state;

    if (state.isLoading && state.items.isEmpty && widget.header == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: colors.accent,
      backgroundColor: colors.surface,
      child: ListView.separated(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        itemCount: _itemCount(state),
        separatorBuilder: (context, index) {
          if (widget.header != null && index == 0) return const SizedBox.shrink();
          return Divider(height: 1, thickness: 1, color: colors.border);
        },
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: widget.header!,
            );
          }

          final offset = widget.header != null ? 1 : 0;
          final adjusted = index - offset;

          if (state.items.isEmpty) {
            return state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _empty(context);
          }

          if (adjusted >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return _buildPost(context, state.items[adjusted]);
        },
      ),
    );
  }

  Widget _buildPost(BuildContext context, Story story) {
    final post = StoryPost(
      story: story,
      showVisibility: widget.showVisibility,
      onTap: () => widget.onOpen(story),
      onLike: widget.onLike == null ? null : () => widget.onLike!(story),
    );

    if (widget.onSwipe == null) return post;

    final colors = context.colors;
    final secondary = story.isDraft ? SwipeAction.publish : SwipeAction.archive;

    return Dismissible(
      key: ValueKey(story.storyId),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: story.isDraft ? colors.success : colors.surfaceRaised,
        icon: story.isDraft ? Icons.publish_rounded : Icons.archive_outlined,
        label: story.isDraft ? 'Publish' : 'To drafts',
        foreground: story.isDraft ? colors.bg : colors.textPrimary,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: colors.danger,
        icon: Icons.delete_outline,
        label: 'Delete',
        foreground: colors.bg,
      ),
      confirmDismiss: (direction) => widget.onSwipe!(
        story,
        direction == DismissDirection.endToStart ? SwipeAction.delete : secondary,
      ),
      child: post,
    );
  }

  int _itemCount(StoryListState state) {
    final headerCount = widget.header != null ? 1 : 0;
    if (state.items.isEmpty) return headerCount + 1;
    return headerCount + state.items.length + (state.isLoadingMore ? 1 : 0);
  }

  Widget _empty(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 44, color: colors.textMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.emptyTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.emptyBody.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.emptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.body,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: AppSizes.iconMd),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: AppTypeScale.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
