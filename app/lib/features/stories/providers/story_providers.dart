import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/theme_provider.dart';
import '../data/story_repository.dart';
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
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;
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
    state = state.copyWith(isLoading: false, isLoadingMore: false, error: message);
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

final feedProvider = NotifierProvider<FeedNotifier, StoryListState>(FeedNotifier.new);

class FeedNotifier extends StoryListNotifier {
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
                .write(success.value.items.map((item) => item.toJson()).toList()),
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

final storyDetailProvider = FutureProvider.family<Story, String>((ref, storyId) async {
  final result = await ref.watch(storyRepositoryProvider).byId(storyId);
  final story = result.valueOrNull;
  if (story == null) throw Exception(result.failureOrNull?.message ?? 'Not found');
  return story;
});

final commentsProvider = FutureProvider.family<List<Comment>, String>((ref, storyId) async {
  final result = await ref.watch(storyRepositoryProvider).comments(storyId);
  return result.valueOrNull ?? const [];
});
