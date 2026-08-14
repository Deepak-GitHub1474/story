import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_sheet.dart';
import '../../../components/skeleton.dart';
import '../../../routing/routes.dart';
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
  String? storyAuthorId,
}) => showAppSheet<void>(
  context: context,
  initialSize: 0.68,
  shell: (sheetContext, scrollController) => CommentsSheet(
    storyId: storyId,
    storyAuthorId: storyAuthorId,
    scrollController: scrollController,
  ),
);

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({
    super.key,
    required this.storyId,
    this.storyAuthorId,
    this.scrollController,
  });

  final String storyId;
  final String? storyAuthorId;
  final ScrollController? scrollController;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _composer = TextEditingController();
  final _liked = <String, bool>{};
  final _openThreads = <String>{};
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
    ref
        .read(commentsProvider(widget.storyId).notifier)
        .removeLocally(comment.commentId);
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

  Future<void> _toggleThread(Comment comment) async {
    final isOpen = _openThreads.contains(comment.commentId);
    setState(() {
      if (isOpen) {
        _openThreads.remove(comment.commentId);
      } else {
        _openThreads.add(comment.commentId);
      }
    });
    if (!isOpen) {
      await ref
          .read(commentsProvider(widget.storyId).notifier)
          .loadReplies(comment.commentId);
    }
  }

  void _openProfile(StoryAuthor author) {
    if (!author.isReachable) return;
    Navigator.of(context).pop();
    context.push('${Routes.user}/${author.username}');
  }

  Comment _withLocalLike(Comment comment) {
    if (!_liked.containsKey(comment.commentId)) return comment;

    final liked = _liked[comment.commentId]!;
    return comment.copyWith(
      isLiked: liked,
      likes: comment.likes + (liked == comment.isLiked ? 0 : (liked ? 1 : -1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final comments = ref.watch(commentsProvider(widget.storyId));
    final me = ref.watch(authProvider).user?.userId;
    final isMyStory = me != null && me == widget.storyAuthorId;

    return AppSheet(
      title: 'Comments',
      scrollController: widget.scrollController,
      footer: CommentComposer(
        controller: _composer,
        isSending: _isSending,
        onSend: _send,
        replyingTo: _replyingTo?.author.handle,
        onCancelReply: () => setState(() => _replyingTo = null),
      ),
      body: comments.when(
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
                controller: widget.scrollController,
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
            : ListView.builder(
                controller: widget.scrollController,
                padding: AppSheet.insets,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final comment = items[index];

                  return CommentTile(
                    comment: _withLocalLike(comment),
                    storyAuthorId: widget.storyAuthorId,
                    canDelete: comment.author.userId == me || isMyStory,
                    canEdit: comment.author.userId == me,
                    isThreadOpen: _openThreads.contains(comment.commentId),
                    onDelete: () => _delete(comment),
                    onLike: () => _like(comment),
                    onReply: () => setState(() => _replyingTo = comment),
                    onToggleReplies: () => _toggleThread(comment),
                    onAuthorTap: _openProfile,
                    onDeleteReply: _delete,
                    onLikeReply: _like,
                    localLike: _withLocalLike,
                  );
                },
              ),
      ),
    );
  }
}
