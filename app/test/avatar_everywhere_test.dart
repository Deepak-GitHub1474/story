import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';

import 'comment_count_test.dart' show TestRef;

const _me = StoryAuthor(
  userId: 'us_me',
  username: 'deepak',
  displayName: 'deepak',
  avatarSeed: 'OLDSEED',
);

const _someoneElse = StoryAuthor(
  userId: 'us_other',
  username: 'wren',
  displayName: 'Wren',
  avatarSeed: 'THEIRSEED',
);

Story _story(String id, StoryAuthor author) => Story(
  storyId: id,
  slug: id,
  title: 'A title',
  excerpt: 'An excerpt',
  body: 'A body',
  visibility: 'public',
  publishedAt: '2026-08-14T03:00:00.000Z',
  createdAt: '2026-08-14T03:00:00.000Z',
  updatedAt: '2026-08-14T03:00:00.000Z',
  readingMinutes: 2,
  likes: 3,
  comments: 1,
  isLiked: true,
  author: author,
);

class StubFeed extends FeedNotifier {
  @override
  StoryListState build() => StoryListState(
    items: [_story('st_mine', _me), _story('st_theirs', _someoneElse)],
  );
}

class StubMine extends MyStoriesNotifier {
  @override
  StoryListState build() => StoryListState(items: [_story('st_mine', _me)]);
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    feedProvider.overrideWith(StubFeed.new),
    myStoriesProvider.overrideWith(StubMine.new),
  ],
);

void main() {
  test('a new face reaches the cards already on screen', () {
    final container = _container();
    addTearDown(container.dispose);

    expect(container.read(feedProvider).items.first.author.avatarSeed, 'OLDSEED');

    retintAuthorEverywhere(
      TestRef(container),
      const StoryAuthor(
        userId: 'us_me',
        username: 'deepak',
        displayName: 'Heron',
        avatarSeed: 'NEWSEED',
      ),
    );

    final mine = container.read(feedProvider).items.first;
    expect(mine.author.avatarSeed, 'NEWSEED');
    expect(mine.author.displayName, 'Heron', reason: 'a rename travels too');
    expect(
      container.read(myStoriesProvider).items.single.author.avatarSeed,
      'NEWSEED',
    );
  });

  test('nobody else is repainted', () {
    final container = _container();
    addTearDown(container.dispose);

    retintAuthorEverywhere(
      TestRef(container),
      const StoryAuthor(
        userId: 'us_me',
        username: 'deepak',
        displayName: 'Heron',
        avatarSeed: 'NEWSEED',
      ),
    );

    final theirs = container.read(feedProvider).items.last;
    expect(theirs.author.avatarSeed, 'THEIRSEED');
    expect(theirs.author.displayName, 'Wren');
  });

  test('the story itself is untouched', () {
    final container = _container();
    addTearDown(container.dispose);

    retintAuthorEverywhere(
      TestRef(container),
      const StoryAuthor(
        userId: 'us_me',
        username: 'deepak',
        displayName: 'Heron',
        avatarSeed: 'NEWSEED',
      ),
    );

    final mine = container.read(feedProvider).items.first;
    expect(mine.isLiked, isTrue);
    expect(mine.likes, 3);
    expect(mine.title, 'A title');
  });
}
