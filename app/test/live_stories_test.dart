@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/auth/data/auth_repository.dart';
import 'package:story_app/features/stories/data/story_repository.dart';

String uniqueUsername() =>
    'w${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

Future<(StoryRepository, SecureStore)> signedIn() async {
  final store = SecureStore(InMemoryStore());
  final client = ApiClient(store: store);
  final auth = AuthRepository(client);

  final session = (await auth.signup(
    username: uniqueUsername(),
    password: 'a-long-enough-password',
    tncAccepted: true,
  )).valueOrNull!;

  await store.saveTokens(
    accessToken: session.tokens.accessToken,
    refreshToken: session.tokens.refreshToken,
  );
  return (StoryRepository(client), store);
}

void main() {
  test('creating a story returns a draft', () async {
    final (stories, _) = await signedIn();
    final story = (await stories.create(
      title: 'A quiet year',
      body: 'It has been a long year and I have not said any of it out loud.',
    )).valueOrNull;

    expect(story, isNotNull);
    expect(story!.visibility, 'draft');
    expect(story.excerpt, isNotEmpty);
    expect(story.readingMinutes, greaterThanOrEqualTo(1));
  });

  test('publishing makes it public and gives it a slug', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Something worth saying out loud.'))
        .valueOrNull!;

    final published = (await stories.publish(
      draft.storyId,
      visibility: 'public',
    )).valueOrNull!;

    expect(published.visibility, 'public');
    expect(published.slug, isNotNull);
    expect(published.publishedAt, isNotNull);
  });

  test('a published story reaches the feed', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Feed visible content here.')).valueOrNull!;
    await stories.publish(draft.storyId, visibility: 'public');

    final (reader, _) = await signedIn();
    final feed = (await reader.feed()).valueOrNull!;

    expect(feed.items.any((item) => item.storyId == draft.storyId), isTrue);
  });

  test('a private story stays out of the feed', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Private thoughts only.')).valueOrNull!;
    await stories.publish(draft.storyId, visibility: 'private');

    final (reader, _) = await signedIn();
    final feed = (await reader.feed()).valueOrNull!;

    expect(feed.items.any((item) => item.storyId == draft.storyId), isFalse);
  });

  test('drafts appear in my own list', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Draft that stays mine.')).valueOrNull!;

    final mine = (await stories.mine(visibility: 'draft')).valueOrNull!;
    expect(mine.items.single.storyId, draft.storyId);
  });

  test('liking and unliking moves the count', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Like this one please.')).valueOrNull!;
    await stories.publish(draft.storyId, visibility: 'public');

    final (reader, _) = await signedIn();
    expect((await reader.setLike(draft.storyId, liked: true)).valueOrNull, 1);
    expect((await reader.setLike(draft.storyId, liked: true)).valueOrNull, 1);
    expect((await reader.setLike(draft.storyId, liked: false)).valueOrNull, 0);
  });

  test('commenting appears in the thread', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Comment on this.')).valueOrNull!;
    await stories.publish(draft.storyId, visibility: 'public');

    final (reader, _) = await signedIn();
    await reader.addComment(draft.storyId, 'I read this twice.');

    final comments = (await reader.comments(draft.storyId)).valueOrNull!;
    expect(comments.single.body, 'I read this twice.');
  });

  test('editing a draft updates the excerpt', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'First version of it.')).valueOrNull!;

    final updated = (await stories.update(
      draft.storyId,
      body: 'Completely rewritten now.',
    )).valueOrNull!;

    expect(updated.excerpt, startsWith('Completely rewritten'));
  });

  test('deleting removes it from my list', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Delete this one.')).valueOrNull!;

    await stories.remove(draft.storyId);
    final mine = (await stories.mine()).valueOrNull!;

    expect(mine.items.any((item) => item.storyId == draft.storyId), isFalse);
  });

  test('another users draft is not readable', () async {
    final (stories, _) = await signedIn();
    final draft = (await stories.create(body: 'Nobody else sees this.')).valueOrNull!;

    final (reader, _) = await signedIn();
    final result = await reader.byId(draft.storyId);

    expect(result.failureOrNull!.code, 'STORY_NOT_FOUND');
  });
}
