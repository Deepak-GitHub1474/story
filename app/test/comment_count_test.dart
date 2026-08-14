import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';

Story aStory({required int comments}) => Story(
  storyId: 'st_1',
  slug: 'a-slug',
  title: 'A title',
  excerpt: 'An excerpt',
  body: 'A body',
  visibility: 'public',
  publishedAt: '2026-08-14T03:00:00.000Z',
  createdAt: '2026-08-14T03:00:00.000Z',
  updatedAt: '2026-08-14T03:00:00.000Z',
  readingMinutes: 2,
  likes: 0,
  comments: comments,
  isLiked: false,
  author: const StoryAuthor(
    userId: 'us_1',
    username: 'deepak',
    displayName: 'deepak',
    avatarSeed: 'seed',
  ),
);

class StubFeed extends FeedNotifier {
  @override
  StoryListState build() => StoryListState(items: [aStory(comments: 0)]);
}

class StubMine extends MyStoriesNotifier {
  @override
  StoryListState build() => StoryListState(items: [aStory(comments: 0)]);
}

void main() {
  test('a new comment lands on the card behind the drawer', () async {
    final container = ProviderContainer(
      overrides: [
        feedProvider.overrideWith(StubFeed.new),
        myStoriesProvider.overrideWith(StubMine.new),
        storyDetailProvider('st_1').overrideWith((ref) async {
          return aStory(comments: 1);
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(feedProvider).items.single.comments, 0);

    await refreshStoryEverywhere(TestRef(container), 'st_1');

    expect(
      container.read(feedProvider).items.single.comments,
      1,
      reason: 'the feed card must not keep the count from before the comment',
    );
    expect(container.read(myStoriesProvider).items.single.comments, 1);
  });

  test('a story that will not load leaves the card as it was', () async {
    final container = ProviderContainer(
      overrides: [
        feedProvider.overrideWith(StubFeed.new),
        myStoriesProvider.overrideWith(StubMine.new),
        storyDetailProvider('st_1').overrideWith(
          (ref) async => throw Exception('offline'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await refreshStoryEverywhere(TestRef(container), 'st_1');

    expect(container.read(feedProvider).items.single.comments, 0);
  });
}

class TestRef implements WidgetRef {
  TestRef(this.container);

  final ProviderContainer container;

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  void invalidate(ProviderOrFamily provider, {bool asReload = false}) =>
      container.invalidate(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('only read and invalidate are needed here');
}
