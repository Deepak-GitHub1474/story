import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/skeleton.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import 'comment_composer.dart';
import 'comment_tile.dart';

Future<void> showCommentsSheet({
  required BuildContext context,
  required String storyId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => CommentsSheet(storyId: storyId),
);

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _composer = TextEditingController();
  final _liked = <String, bool>{};
  Comment? _replyingTo;
  bool _isSending = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    final me = ref.read(authProvider).user;
    if (me == null) return;

    setState(() => _isSending = true);
    await ref
        .read(commentsProvider(widget.storyId).notifier)
        .add(text, replyTo: _replyingTo, me: me);

    if (!mounted) return;
    _composer.clear();
    setState(() {
      _isSending = false;
      _replyingTo = null;
    });
  }

  Future<void> _delete(Comment comment) async {
    ref.read(commentsProvider(widget.storyId).notifier).removeLocally(comment.commentId);
    await ref.read(storyRepositoryProvider).deleteComment(comment.commentId);
    if (!mounted) return;
    await ref.read(commentsProvider(widget.storyId).notifier).refresh();
    ref.invalidate(storyDetailProvider(widget.storyId));
  }

  Future<void> _like(Comment comment) async {
    setState(() => _liked[comment.commentId] = !_isLiked(comment));
    await ref
        .read(storyRepositoryProvider)
        .setCommentLike(comment.commentId, liked: _liked[comment.commentId]!);
  }

  bool _isLiked(Comment comment) =>
      _liked[comment.commentId] ?? comment.isLiked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final comments = ref.watch(commentsProvider(widget.storyId));
    final me = ref.watch(authProvider).user?.userId;
    final media = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.45,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) => Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Comments',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: colors.border),
          Expanded(
            child: comments.when(
              loading: () => const SkeletonList(count: 4),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Could not load the comments.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              data: (items) => items.isEmpty
                  ? ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      children: [
                        Column(
                        children: [
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: AppTypeScale.body,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Say something kind.',
                            style: TextStyle(color: colors.textMuted),
                          ),
                        ],
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final comment = items[index];

                        final shown = _liked.containsKey(comment.commentId)
                            ? comment.copyWith(
                                isLiked: _liked[comment.commentId],
                                likes: comment.likes +
                                    (_liked[comment.commentId]! == comment.isLiked
                                        ? 0
                                        : (_liked[comment.commentId]! ? 1 : -1)),
                              )
                            : comment;

                        return CommentTile(
                          comment: shown,
                          canDelete: comment.author.userId == me,
                          canEdit: comment.author.userId == me,
                          onDelete: () => _delete(comment),
                          onLike: () => _like(comment),
                          onReply: () => setState(() => _replyingTo = comment),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: CommentComposer(
              controller: _composer,
              isSending: _isSending,
              onSend: _send,
              replyingTo: _replyingTo?.author.handle,
              onCancelReply: () => setState(() => _replyingTo = null),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
