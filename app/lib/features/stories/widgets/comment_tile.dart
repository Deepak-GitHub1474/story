import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../components/expandable_text.dart';
import '../../../core/utils/time_ago.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';
import 'story_post.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.canDelete,
    required this.onDelete,
    required this.onLike,
    required this.onReply,
    this.storyAuthorId,
    this.canEdit = false,
    this.onEdit,
    this.onToggleReplies,
    this.onAuthorTap,
    this.onDeleteReply,
    this.onLikeReply,
    this.localLike,
    this.isThreadOpen = false,
    this.isReply = false,
  });

  final Comment comment;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final String? storyAuthorId;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleReplies;
  final void Function(StoryAuthor author)? onAuthorTap;
  final void Function(Comment reply)? onDeleteReply;
  final void Function(Comment reply)? onLikeReply;
  final Comment Function(Comment comment)? localLike;
  final bool isThreadOpen;
  final bool isReply;

  bool get _isStoryAuthor =>
      storyAuthorId != null && comment.author.userId == storyAuthorId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final replies = isThreadOpen ? comment.replies : const <Comment>[];
    final waiting = comment.replyCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: isReply ? AppSpacing.xxl : 0,
            bottom: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onAuthorTap?.call(comment.author),
                child: AppAvatar(
                  seed: comment.author.avatarSeed,
                  size: isReply ? 26 : 32,
                  displayName: comment.author.displayName,
                  username: comment.author.username,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => onAuthorTap?.call(comment.author),
                            child: Text(
                              comment.author.handle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.label,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          timeAgoLong(comment.createdAt),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.caption,
                          ),
                        ),
                        if (comment.editedAt != null)
                          Text(
                            ' · edited',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: AppTypeScale.caption,
                            ),
                          ),
                        if (_isStoryAuthor)
                          Text(
                            ' · Author',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: AppTypeScale.caption,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ExpandableText(
                      collapsedLines: 4,
                      text: TextSpan(
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.label,
                          height: 1.45,
                        ),
                        children: _bodySpans(context, comment.body),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (comment.likes > 0) ...[
                          _Action(
                            label:
                                '${comment.likes} ${comment.likes == 1 ? 'like' : 'likes'}',
                            onTap: null,
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        _Action(label: 'Reply', onTap: onReply),
                        if (canEdit && onEdit != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          _Action(label: 'Edit', onTap: onEdit),
                        ],
                        const SizedBox(width: AppSpacing.md),
                        _Action(
                          label: canDelete ? 'Delete' : 'Report',
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  top: AppSpacing.xs,
                ),
                child: LikeIcon(
                  isLiked: comment.isLiked,
                  onTap: onLike,
                  size: AppSizes.iconSm,
                ),
              ),
            ],
          ),
        ),
        for (final reply in replies)
          CommentTile(
            key: ValueKey(reply.commentId),
            comment: localLike?.call(reply) ?? reply,
            storyAuthorId: storyAuthorId,
            canDelete: canDelete || reply.author.userId == storyAuthorId,
            isReply: true,
            onDelete: () => (onDeleteReply ?? (_) => onDelete())(reply),
            onLike: () => (onLikeReply ?? (_) => onLike())(reply),
            onReply: onReply,
            onAuthorTap: onAuthorTap,
          ),
        if (waiting > 0 && onToggleReplies != null && !isReply)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxl,
              bottom: AppSpacing.lg,
            ),
            child: InkWell(
              onTap: onToggleReplies,
              child: Row(
                children: [
                  Container(width: 24, height: 1, color: colors.border),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isThreadOpen
                        ? 'Hide replies'
                        : 'View $waiting more ${waiting == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<InlineSpan> _bodySpans(BuildContext context, String body) {
    final colors = context.colors;
    final pattern = RegExp(r'(@[a-z0-9][a-z0-9_-]*)');
    final spans = <InlineSpan>[];
    var index = 0;

    for (final match in pattern.allMatches(body)) {
      if (match.start > index) {
        spans.add(TextSpan(text: body.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: colors.accent, fontWeight: FontWeight.w500),
        ),
      );
      index = match.end;
    }

    if (index < body.length) spans.add(TextSpan(text: body.substring(index)));
    return spans;
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: AppTypeScale.caption,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
