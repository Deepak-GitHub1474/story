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
    this.canEdit = false,
    this.onEdit,
    this.onExpandReplies,
    this.isReply = false,
    this.expandedReplies = const [],
    this.isExpanded = false,
  });

  final Comment comment;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onExpandReplies;
  final bool isReply;
  final List<Comment> expandedReplies;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visibleReplies = isExpanded ? expandedReplies : comment.replies;
    final hidden = comment.replyCount - visibleReplies.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: isReply ? AppSpacing.xxl : 0,
            bottom: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                seed: comment.author.avatarSeed,
                size: isReply ? 24 : 30,
                displayName: comment.author.displayName,
                username: comment.author.username,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExpandableText(
                      collapsedLines: 4,
                      text: TextSpan(
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.body,
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                            text: comment.author.handle,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          ..._bodySpans(context, comment.body),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          comment.editedAt == null
                              ? timeAgo(comment.createdAt)
                              : '${timeAgo(comment.createdAt)} · edited',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.caption,
                          ),
                        ),
                        if (comment.likes > 0) ...[
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            '${comment.likes} ${comment.likes == 1 ? 'like' : 'likes'}',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: AppTypeScale.caption,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(width: AppSpacing.md),
                        InkWell(
                          onTap: onReply,
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: AppTypeScale.caption,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (canEdit && onEdit != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          InkWell(
                            onTap: onEdit,
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: AppTypeScale.caption,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: AppSpacing.md),
                        InkWell(
                          onTap: onDelete,
                          child: Text(
                            canDelete ? 'Delete' : 'Report',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: AppTypeScale.caption,
                            ),
                          ),
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
        for (final reply in visibleReplies)
          CommentTile(
            key: ValueKey(reply.commentId),
            comment: reply,
            canDelete: canDelete,
            isReply: true,
            onDelete: onDelete,
            onLike: onLike,
            onReply: onReply,
          ),
        if (hidden > 0 && onExpandReplies != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxl,
              bottom: AppSpacing.md,
            ),
            child: InkWell(
              onTap: onExpandReplies,
              child: Row(
                children: [
                  Container(width: 24, height: 1, color: colors.border),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'View $hidden more ${hidden == 1 ? 'reply' : 'replies'}',
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
