import 'package:flutter/material.dart';

import '../../../components/skeleton.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import 'story_post.dart';

enum SwipeAction { delete, archive, publish, makePrivate }

class StoryListView extends StatefulWidget {
  const StoryListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    this.onLike,
    this.onAuthorTap,
    this.onShare,
    this.onOpenShared,
    this.onLongPress,
    this.onComment,
    this.emptyTitle = 'Nothing here yet',
    this.emptyBody = '',
    this.endLabel = 'You are all caught up',
    this.showVisibility = false,
    this.header,
  });

  final StoryListState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final void Function(Story story) onOpen;
  final void Function(Story story)? onLike;
  final void Function(Story story)? onAuthorTap;
  final void Function(Story story)? onShare;
  final void Function(String storyId)? onOpenShared;
  final void Function(Story story)? onLongPress;
  final void Function(Story story)? onComment;
  final String emptyTitle;
  final String emptyBody;
  final String endLabel;
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
      if (!widget.state.hasMore || widget.state.isLoadingMore) return;
      final position = _controller.position;
      if (position.pixels > position.maxScrollExtent - 600) widget.onLoadMore();
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
      return const SkeletonList();
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
            return state.isLoading ? const SkeletonList(count: 3) : _empty(context);
          }

          if (adjusted >= state.items.length) {
            return state.isLoadingMore
                ? const StorySkeleton()
                : EndOfFeed(label: widget.endLabel);
          }

          return _buildPost(context, state.items[adjusted]);
        },
      ),
    );
  }

  Widget _buildPost(BuildContext context, Story story) {
    final post = StoryPost(
      onLongPress: widget.onLongPress == null
          ? null
          : () => widget.onLongPress!(story),
      story: story,
      showVisibility: widget.showVisibility,
      onTap: () => widget.onOpen(story),
      onLike: widget.onLike == null ? null : () => widget.onLike!(story),
      onComment: widget.onComment == null ? null : () => widget.onComment!(story),
      onAuthorTap:
          widget.onAuthorTap == null ? null : () => widget.onAuthorTap!(story),
      onShare: widget.onShare == null || !story.isPublic
          ? null
          : () => widget.onShare!(story),
      onSharedTap: story.shared == null
          ? null
          : () => widget.onOpenShared?.call(story.shared!.storyId),
    );

    return post;
  }

  int _itemCount(StoryListState state) {
    final headerCount = widget.header != null ? 1 : 0;
    if (state.items.isEmpty) return headerCount + 1;
    final trailing = state.isLoadingMore || !state.hasMore ? 1 : 0;
    return headerCount + state.items.length + trailing;
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
              fontWeight: FontWeight.w500,
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

