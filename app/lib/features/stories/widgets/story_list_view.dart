import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import 'story_card.dart';

class StoryListView extends StatefulWidget {
  const StoryListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    this.onLike,
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

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: colors.accent,
      backgroundColor: colors.surface,
      child: ListView.separated(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        itemCount: _itemCount(state),
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) return widget.header!;

          final offset = widget.header != null ? 1 : 0;
          final adjusted = index - offset;

          if (state.items.isEmpty) return _empty(context);

          if (adjusted >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final story = state.items[adjusted];
          return TweenAnimationBuilder<double>(
            key: ValueKey(story.storyId),
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.base,
            curve: AppMotion.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: child,
              ),
            ),
            child: StoryCard(
              story: story,
              showVisibility: widget.showVisibility,
              onTap: () => widget.onOpen(story),
              onLike: widget.onLike == null ? null : () => widget.onLike!(story),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.only(top: AppSpacing.xxxl * 2),
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
