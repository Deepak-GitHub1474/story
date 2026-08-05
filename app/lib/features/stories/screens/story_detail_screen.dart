import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_toast.dart';
import '../../../core/utils/time_ago.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/theme_provider.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';

class StoryDetailScreen extends ConsumerStatefulWidget {
  const StoryDetailScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends ConsumerState<StoryDetailScreen> {
  final _comment = TextEditingController();
  bool _isSending = false;
  Story? _story;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(Story story) async {
    final next = !story.isLiked;
    setState(() {
      _story = story.copyWith(
        isLiked: next,
        likes: story.likes + (next ? 1 : -1),
      );
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .setLike(story.storyId, liked: next);

    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _story = _story!.copyWith(likes: result.valueOrNull));
      ref.read(feedProvider.notifier).replace(_story!);
    } else {
      setState(() => _story = story);
    }
  }

  Future<void> _send(String storyId) async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final result = await ref.read(storyRepositoryProvider).addComment(storyId, text);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.isSuccess) {
      _comment.clear();
      FocusScope.of(context).unfocus();
      ref.invalidate(commentsProvider(storyId));
      ref.invalidate(storyDetailProvider(storyId));
    } else {
      AppToast.show(context, result.failureOrNull!.message, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final asyncStory = ref.watch(storyDetailProvider(widget.storyId));
    final comments = ref.watch(commentsProvider(widget.storyId));
    final readingSize = ref.watch(readingSizeProvider);
    final bodySize = readingSize == 'readingLg'
        ? AppTypeScale.reading + 2
        : AppTypeScale.reading;
    final currentUserId = ref.watch(authProvider).user?.userId;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: asyncStory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'This story is not available.',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ),
        data: (fetched) {
          final story = _story ?? fetched;
          final isMine = story.author.userId == currentUserId;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: [
                    Row(
                      children: [
                        AppAvatar(seed: story.author.avatarSeed, size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                story.author.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: AppTypeScale.body,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${timeAgo(story.publishedAt ?? story.createdAt)} · ${story.readingMinutes} min read',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: AppTypeScale.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isMine)
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: colors.textMuted),
                            onPressed: () =>
                                context.push('${Routes.compose}?id=${story.storyId}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (story.title != null && story.title!.isNotEmpty) ...[
                      Text(
                        story.title!,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppTypeScale.title,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    SelectableText(
                      story.body ?? story.excerpt,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: bodySize,
                        height: 1.75,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _toggleLike(story),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                AnimatedScale(
                                  scale: story.isLiked ? 1.2 : 1,
                                  duration: AppMotion.fast,
                                  curve: AppMotion.easeOut,
                                  child: Icon(
                                    story.isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: story.isLiked
                                        ? colors.danger
                                        : colors.textMuted,
                                    size: AppSizes.iconMd,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '${story.likes}',
                                  style: TextStyle(
                                    color: story.isLiked
                                        ? colors.danger
                                        : colors.textMuted,
                                    fontSize: AppTypeScale.label,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: colors.border, height: AppSpacing.xxl),
                    Text(
                      'Comments',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    comments.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                              child: Text(
                                'No comments yet. Be the first to say something that is not advice.',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: AppTypeScale.label,
                                  height: 1.5,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final comment in items)
                                  _CommentTile(
                                    comment: comment,
                                    canDelete:
                                        comment.author.userId == currentUserId || isMine,
                                    onDelete: () async {
                                      await ref
                                          .read(storyRepositoryProvider)
                                          .deleteComment(comment.commentId);
                                      ref.invalidate(commentsProvider(story.storyId));
                                      ref.invalidate(storyDetailProvider(story.storyId));
                                    },
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comment,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Say something kind',
                            hintStyle: TextStyle(color: colors.textMuted),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: AppSizes.iconSm,
                                height: AppSizes.iconSm,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: _comment.text.trim().isEmpty
                                    ? colors.textMuted
                                    : colors.accent,
                              ),
                        onPressed: _comment.text.trim().isEmpty || _isSending
                            ? null
                            : () => _send(story.storyId),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final Comment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(seed: comment.author.avatarSeed, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author.displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.label,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      timeAgo(comment.createdAt),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  comment.body,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppTypeScale.body,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            InkWell(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.close,
                  size: AppSizes.iconSm,
                  color: colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
