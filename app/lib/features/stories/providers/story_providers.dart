import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/theme_provider.dart';
import '../data/story_repository.dart';
import '../../auth/models/auth_models.dart';
import '../models/story_models.dart';

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => StoryRepository(ref.watch(apiClientProvider)),
);

class StoryListState {
  const StoryListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
  });

  final List<Story> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  StoryListState copyWith({
    List<Story>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
  }) => StoryListState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    nextCursor: nextCursor ?? this.nextCursor,
    error: clearError ? null : (error ?? this.error),
  );
}

abstract class StoryListNotifier extends Notifier<StoryListState> {
  Future<void> fetch({String? cursor});

  @override
  StoryListState build() {
    Future.microtask(refresh);
    return const StoryListState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await fetch();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    await fetch(cursor: state.nextCursor);
  }

  void apply(StoryPage page, {required bool append}) {
    state = StoryListState(
      items: append ? [...state.items, ...page.items] : page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  void fail(String message) {
    state = state.copyWith(
      isLoading: false,
      isLoadingMore: false,
      error: message,
    );
  }

  void replace(Story story) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.storyId == story.storyId) story else item,
      ],
    );
  }

  void remove(String storyId) {
    state = state.copyWith(
      items: state.items.where((item) => item.storyId != storyId).toList(),
    );
  }
}

final feedProvider = NotifierProvider<FeedNotifier, StoryListState>(
  FeedNotifier.new,
);

class FeedNotifier extends StoryListNotifier {
  @override
  void remove(String storyId) {
    super.remove(storyId);
    unawaited(
      ref
          .read(feedCacheProvider)
          .write(state.items.map((item) => item.toJson()).toList()),
    );
  }

  @override
  StoryListState build() {
    final cached = ref.read(feedCacheProvider).read();
    Future.microtask(refresh);

    if (cached.isEmpty) return const StoryListState(isLoading: true);
    return StoryListState(
      items: cached.map(Story.fromJson).toList(),
      isLoading: false,
      hasMore: true,
    );
  }

  @override
  Future<void> refresh() async {
    if (state.items.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    await fetch();
  }

  @override
  Future<void> fetch({String? cursor}) async {
    final result = await ref.read(storyRepositoryProvider).feed(cursor: cursor);
    result.fold(
      onSuccess: (success) {
        apply(success.value, append: cursor != null);
        if (cursor == null) {
          unawaited(
            ref
                .read(feedCacheProvider)
                .write(
                  success.value.items.map((item) => item.toJson()).toList(),
                ),
          );
        }
      },
      onFailure: (failure) {
        if (state.items.isEmpty) {
          fail(failure.message);
        } else {
          state = state.copyWith(isLoading: false, isLoadingMore: false);
        }
      },
    );
  }
}

void _echoEverywhere(WidgetRef ref, Story story) {
  ref.read(feedProvider.notifier).replace(story);
  ref.read(myStoriesProvider.notifier).replace(story);
}

Future<void> toggleStoryLike(WidgetRef ref, Story story) async {
  final next = !story.isLiked;

  _echoEverywhere(
    ref,
    story.copyWith(isLiked: next, likes: story.likes + (next ? 1 : -1)),
  );

  final result = await ref
      .read(storyRepositoryProvider)
      .setLike(story.storyId, liked: next);

  _echoEverywhere(
    ref,
    result.isSuccess
        ? story.copyWith(isLiked: next, likes: result.valueOrNull)
        : story,
  );
}

final myStoriesProvider = NotifierProvider<MyStoriesNotifier, StoryListState>(
  MyStoriesNotifier.new,
);

class MyStoriesNotifier extends StoryListNotifier {
  String? _visibility;

  @override
  Future<void> fetch({String? cursor}) async {
    final result = await ref
        .read(storyRepositoryProvider)
        .mine(visibility: _visibility, cursor: cursor);
    result.fold(
      onSuccess: (success) => apply(success.value, append: cursor != null),
      onFailure: (failure) => fail(failure.message),
    );
  }

  Future<void> filter(String? visibility) async {
    _visibility = visibility;
    await refresh();
  }

  String? get visibility => _visibility;
}

Future<void> refreshStoryEverywhere(WidgetRef ref, String storyId) async {
  ref.invalidate(storyDetailProvider(storyId));

  final result = await ref.read(storyRepositoryProvider).byId(storyId);
  final story = result.valueOrNull;
  if (story == null) return;

  _echoEverywhere(ref, story);
}

final storyDetailProvider = FutureProvider.family<Story, String>((
  ref,
  storyId,
) async {
  final result = await ref.watch(storyRepositoryProvider).byId(storyId);
  final story = result.valueOrNull;
  if (story == null) {
    throw Exception(result.failureOrNull?.message ?? 'Not found');
  }
  return story;
});

final commentsProvider =
    AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, String>(
      CommentsNotifier.new,
    );

class CommentsNotifier extends FamilyAsyncNotifier<List<Comment>, String> {
  @override
  Future<List<Comment>> build(String storyId) async {
    final result = await ref.watch(storyRepositoryProvider).comments(storyId);
    return result.valueOrNull ?? const [];
  }

  Future<bool> add(String text, {Comment? replyTo, required AppUser me}) async {
    final parentId = replyTo?.parentId ?? replyTo?.commentId;
    final pending = Comment(
      commentId: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      storyId: arg,
      parentId: parentId,
      author: StoryAuthor(
        userId: me.userId,
        username: me.username,
        displayName: me.displayName,
        avatarSeed: me.avatarSeed,
      ),
      body: text,
      likes: 0,
      replyCount: 0,
      isLiked: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    state = AsyncData(_insert(state.valueOrNull ?? const [], pending));

    final result = await ref
        .read(storyRepositoryProvider)
        .addComment(arg, text, parentId: parentId);

    if (result.isFailure) {
      state = AsyncData(
        _remove(state.valueOrNull ?? const [], pending.commentId),
      );
      return false;
    }

    await refresh();
    return true;
  }

  Future<void> refresh() async {
    final result = await ref.read(storyRepositoryProvider).comments(arg);
    state = AsyncData(result.valueOrNull ?? const []);
  }

  Future<void> loadReplies(String commentId) async {
    final result = await ref.read(storyRepositoryProvider).replies(commentId);
    final replies = result.valueOrNull;
    if (replies == null) return;

    state = AsyncData([
      for (final comment in state.valueOrNull ?? const <Comment>[])
        if (comment.commentId == commentId)
          comment.copyWith(replies: replies)
        else
          comment,
    ]);
  }

  void removeLocally(String commentId) {
    state = AsyncData(_remove(state.valueOrNull ?? const [], commentId));
  }

  static List<Comment> _insert(List<Comment> current, Comment pending) {
    if (pending.parentId == null) return [...current, pending];

    return [
      for (final comment in current)
        if (comment.commentId == pending.parentId)
          comment.copyWith(replies: [...comment.replies, pending])
        else
          comment,
    ];
  }

  static List<Comment> _remove(List<Comment> current, String commentId) => [
    for (final comment in current)
      if (comment.commentId != commentId)
        comment.copyWith(
          replies: comment.replies
              .where((reply) => reply.commentId != commentId)
              .toList(),
        ),
  ];
}
