import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';

import 'comment_count_test.dart' show TestRef;

Story aStory({required String excerpt, required String body}) => Story(
  storyId: 'st_1',
  slug: 'a-slug',
  title: 'A title',
  excerpt: excerpt,
  body: body,
  visibility: 'public',
  publishedAt: '2026-08-14T03:00:00.000Z',
  createdAt: '2026-08-14T03:00:00.000Z',
  updatedAt: '2026-08-14T03:00:00.000Z',
  readingMinutes: 2,
  likes: 3,
  comments: 1,
  isLiked: true,
  author: const StoryAuthor(
    userId: 'us_1',
    username: 'deepak',
    displayName: 'deepak',
    avatarSeed: 'seed',
  ),
);

class StubFeed extends FeedNotifier {
  @override
  StoryListState build() => StoryListState(
    items: [aStory(excerpt: 'ORIGINAL words', body: 'ORIGINAL words in full')],
  );
}

class StubMine extends MyStoriesNotifier {
  @override
  StoryListState build() => StoryListState(
    items: [aStory(excerpt: 'ORIGINAL words', body: 'ORIGINAL words in full')],
  );
}

ProviderContainer withEdit(Story edited) => ProviderContainer(
  overrides: [
    feedProvider.overrideWith(StubFeed.new),
    myStoriesProvider.overrideWith(StubMine.new),
    storyDetailProvider('st_1').overrideWith((ref) async => edited),
  ],
);

void main() {
  test('an edit reaches the card without a pull to refresh', () async {
    final container = withEdit(
      aStory(excerpt: 'EDITED words', body: 'EDITED words in full'),
    );
    addTearDown(container.dispose);

    expect(container.read(feedProvider).items.single.excerpt, 'ORIGINAL words');

    await refreshStoryEverywhere(TestRef(container), 'st_1');

    expect(
      container.read(feedProvider).items.single.excerpt,
      'EDITED words',
      reason: 'the collapsed card reads the excerpt, so it must be replaced',
    );
    expect(
      container.read(myStoriesProvider).items.single.excerpt,
      'EDITED words',
    );
  });

  test('the full text behind more is edited too', () async {
    final container = withEdit(
      aStory(excerpt: 'EDITED words', body: 'EDITED words in full'),
    );
    addTearDown(container.dispose);

    await refreshStoryEverywhere(TestRef(container), 'st_1');

    final story = await container.read(storyDetailProvider('st_1').future);
    expect(story.body, 'EDITED words in full');
  });

  test('an edit does not cost the story its likes', () async {
    final container = withEdit(
      aStory(excerpt: 'EDITED words', body: 'EDITED words in full'),
    );
    addTearDown(container.dispose);

    await refreshStoryEverywhere(TestRef(container), 'st_1');

    final card = container.read(feedProvider).items.single;
    expect(card.isLiked, isTrue, reason: 'the refetch is viewer-aware');
    expect(card.likes, 3);
  });
}
