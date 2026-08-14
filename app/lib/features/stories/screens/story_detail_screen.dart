import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/app_back_button.dart';

import '../../../components/app_sheet.dart';
import '../../../components/story_glyphs.dart';
import '../../../components/story_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../components/report_sheet.dart';
import '../../../core/utils/time_ago.dart';
import '../../../routing/routes.dart';
import '../../../components/skeleton.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/theme_provider.dart';
import '../models/story_models.dart';
import '../providers/story_providers.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_tile.dart';
import '../widgets/liked_by_row.dart';
import '../widgets/likes_sheet.dart';
import '../widgets/share_sheet.dart';
import '../widgets/shared_story_card.dart';
import '../widgets/story_images.dart';
import '../widgets/story_post.dart';

class StoryDetailScreen extends ConsumerStatefulWidget {
  const StoryDetailScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends ConsumerState<StoryDetailScreen> {
  final _comment = TextEditingController();
  final _commentFocus = FocusNode();

  final Map<String, List<Comment>> _expanded = {};
  final Map<String, Comment> _overrides = {};

  bool _isSending = false;
  Story? _story;
  Comment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Comment _resolve(Comment comment) => _overrides[comment.commentId] ?? comment;

  Future<void> _toggleStoryLike(Story story) async {
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

  Future<void> _toggleCommentLike(Comment comment) async {
    final next = !comment.isLiked;
    setState(() {
      _overrides[comment.commentId] = comment.copyWith(
        isLiked: next,
        likes: comment.likes + (next ? 1 : -1),
      );
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .setCommentLike(comment.commentId, liked: next);

    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _overrides[comment.commentId] = _overrides[comment.commentId]!.copyWith(
          likes: result.valueOrNull,
        );
      });
    } else {
      setState(() => _overrides[comment.commentId] = comment);
    }
  }

  Future<void> _expandReplies(Comment comment) async {
    if (_expanded.containsKey(comment.commentId)) {
      setState(() => _expanded.remove(comment.commentId));
      return;
    }

    final result = await ref
        .read(storyRepositoryProvider)
        .replies(comment.commentId);
    if (!mounted) return;
    final replies = result.valueOrNull;
    if (replies != null) setState(() => _expanded[comment.commentId] = replies);
  }

  Comment _withThread(Comment comment) {
    final replies = _expanded[comment.commentId];
    return replies == null ? comment : comment.copyWith(replies: replies);
  }

  void _startReply(Comment comment) {
    setState(() => _replyTarget = comment);
    final handle = comment.author.username;
    if (handle != null && !_comment.text.contains('@$handle')) {
      _comment.text = '@$handle ${_comment.text}';
      _comment.selection = TextSelection.collapsed(
        offset: _comment.text.length,
      );
    }
    _commentFocus.requestFocus();
  }

  Future<void> _send(String storyId) async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;

    final me = ref.read(authProvider).user;
    if (me == null) return;

    final parent = _replyTarget;
    _comment.clear();
    _commentFocus.unfocus();
    setState(() {
      _isSending = true;
      _replyTarget = null;
    });

    final ok = await ref
        .read(commentsProvider(storyId).notifier)
        .add(text, replyTo: parent, me: me);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (ok) {
      _expanded.clear();
      ref.invalidate(storyDetailProvider(storyId));
    } else {
      _comment.text = text;
      AppToast.show(
        context,
        'That comment did not post.',
        kind: AppToastKind.error,
      );
    }
  }

  bool _canEdit(Comment comment, String? currentUserId) {
    if (comment.author.userId != currentUserId) return false;
    final posted = DateTime.tryParse(comment.createdAt);
    if (posted == null) return false;
    return DateTime.now().toUtc().difference(posted.toUtc()).inMinutes < 15;
  }

  Future<void> _editComment(Comment comment, String storyId) async {
    final controller = TextEditingController(text: comment.body);

    final next = await showAppSheet<String?>(
      context: context,
      title: 'Edit comment',
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: controller,
              label: 'Your comment',
              maxLines: 4,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You can edit a comment for 15 minutes after posting.',
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: AppTypeScale.caption,
              ),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (next == null || next.isEmpty || next == comment.body || !mounted) {
      return;
    }

    final result = await ref
        .read(storyRepositoryProvider)
        .editComment(comment.commentId, next);

    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        _expanded.clear();
        ref.invalidate(commentsProvider(storyId));
      },
      onFailure: (failure) =>
          AppToast.show(context, failure.message, kind: AppToastKind.error),
    );
  }

  Future<void> _deleteComment(Comment comment, String storyId) async {
    ref
        .read(commentsProvider(storyId).notifier)
        .removeLocally(comment.commentId);

    final result = await ref
        .read(storyRepositoryProvider)
        .deleteComment(comment.commentId);
    if (!mounted) return;

    _expanded.clear();
    await ref.read(commentsProvider(storyId).notifier).refresh();
    if (!mounted) return;

    if (result.isFailure) {
      AppToast.show(
        context,
        result.failureOrNull!.message,
        kind: AppToastKind.error,
      );
      return;
    }

    await refreshStoryEverywhere(ref, storyId);
    if (mounted) setState(() => _story = null);
  }

  Future<void> _openStoryMenu(Story story, {required bool isMine}) async {
    final colors = context.colors;

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: colors.textPrimary),
                title: Text(
                  'Edit',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('${Routes.compose}?id=${story.storyId}');
                },
              ),
              if (story.isPublic)
                ListTile(
                  leading: Icon(
                    Icons.archive_outlined,
                    color: colors.textPrimary,
                  ),
                  title: Text(
                    'Move to drafts',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(storyRepositoryProvider)
                        .unpublish(story.storyId);
                    if (!mounted) return;
                    ref.invalidate(storyDetailProvider(story.storyId));
                    unawaited(ref.read(feedProvider.notifier).refresh());
                    unawaited(ref.read(myStoriesProvider.notifier).refresh());
                    AppToast.show(context, 'Moved back to drafts.');
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.danger),
                title: Text('Delete', style: TextStyle(color: colors.danger)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(storyRepositoryProvider).remove(story.storyId);
                  if (!mounted) return;
                  unawaited(ref.read(feedProvider.notifier).refresh());
                  unawaited(ref.read(myStoriesProvider.notifier).refresh());
                  AppToast.show(context, 'Story deleted.');
                  context.pop();
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.flag_outlined, color: colors.textPrimary),
                title: Text(
                  'Report',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showReportSheet(
                    context,
                    ref,
                    targetKind: 'story',
                    targetId: story.storyId,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
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
      appBar: AppBar(leading: const AppBackButton()),
      body: asyncStory.when(
        loading: () => const SkeletonList(count: 3),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    Row(
                      children: [
                        AppAvatar(
                          seed: story.author.avatarSeed,
                          size: 38,
                          displayName: story.author.displayName,
                          username: story.author.username,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                story.author.handle,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: AppTypeScale.body,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${timeAgoLong(story.publishedAt ?? story.createdAt)}'
                                '${story.wasEdited ? ' · Edited' : ''}',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: AppTypeScale.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_horiz, color: colors.textMuted),
                          onPressed: () =>
                              _openStoryMenu(story, isMine: isMine),
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
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if ((story.body ?? story.excerpt).isNotEmpty)
                      StoryText(
                        text: story.body ?? story.excerpt,
                        fontSize: bodySize,
                      ),
                    if (story.images.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      StoryImages(
                        images: story.images,
                        ratio: story.imageRatio,
                        fit: story.imageFit,
                      ),
                    ],
                    if (story.shared != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SharedStoryCard(
                        shared: story.shared!,
                        onTap: () => context.push(
                          '${Routes.story}/${story.shared!.storyId}',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        LikeIcon(
                          isLiked: story.isLiked,
                          onTap: () => _toggleStoryLike(story),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        GestureDetector(
                          onTap: story.likes == 0
                              ? null
                              : () => showLikesSheet(
                                  context: context,
                                  storyId: story.storyId,
                                ),
                          child: Text(
                            '${story.likes}',
                            style: TextStyle(
                              color: story.isLiked
                                  ? AppInk.like
                                  : colors.textMuted,
                              fontSize: AppTypeScale.label,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        CommentGlyph(
                          size: AppSizes.iconAction,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${story.comments}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.label,
                          ),
                        ),
                        if (story.isPublic) ...[
                          const SizedBox(width: AppSpacing.xl),
                          InkResponse(
                            radius: 22,
                            onTap: () => showShareSheet(
                              context: context,
                              ref: ref,
                              story: story,
                            ),
                            child: ShareGlyph(
                              size: AppSizes.iconAction,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (story.likedBy.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      LikedByRow(
                        people: story.likedBy,
                        likes: story.likes,
                        onTap: () => showLikesSheet(
                          context: context,
                          storyId: story.storyId,
                        ),
                      ),
                    ],
                    Divider(color: colors.border, height: AppSpacing.xxl),
                    comments.when(
                      loading: () => const SkeletonList(count: 3),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xl,
                              ),
                              child: Text(
                                'No comments yet. Say something that is not advice.',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: AppTypeScale.label,
                                  height: 1.5,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final raw in items)
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(raw.commentId),
                                    tween: Tween(begin: 0, end: 1),
                                    duration: AppMotion.base,
                                    curve: AppMotion.easeOut,
                                    builder: (context, value, child) => Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - value) * 8),
                                        child: child,
                                      ),
                                    ),
                                    child: CommentTile(
                                      comment: _withThread(_resolve(raw)),
                                      storyAuthorId: story.author.userId,
                                      canDelete:
                                          raw.author.userId == currentUserId ||
                                          isMine,
                                      isThreadOpen: _expanded.containsKey(
                                        raw.commentId,
                                      ),
                                      onAuthorTap: (author) => author.isReachable
                                          ? context.push(
                                              '${Routes.user}/${author.username}',
                                            )
                                          : null,
                                      onDelete: () =>
                                          _deleteComment(raw, story.storyId),
                                      canEdit: _canEdit(raw, currentUserId),
                                      onEdit: () => _editComment(
                                        _resolve(raw),
                                        story.storyId,
                                      ),
                                      onLike: () =>
                                          _toggleCommentLike(_resolve(raw)),
                                      onReply: () => _startReply(raw),
                                      onToggleReplies: () =>
                                          _expandReplies(raw),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              CommentComposer(
                controller: _comment,
                isSending: _isSending,
                replyingTo: _replyTarget?.author.handle,
                onCancelReply: () => setState(() => _replyTarget = null),
                onSend: () => _send(story.storyId),
              ),
            ],
          );
        },
      ),
    );
  }
}
