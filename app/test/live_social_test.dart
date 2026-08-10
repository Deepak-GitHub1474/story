@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/auth/data/auth_repository.dart';
import 'package:story_app/features/communities/data/community_repository.dart';
import 'package:story_app/features/stories/data/story_repository.dart';

String uniqueUsername() =>
    's${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

class Session {
  Session(this.username, this.stories, this.communities, this.client);

  final String username;
  final StoryRepository stories;
  final CommunityRepository communities;
  final ApiClient client;
}

Future<Session> signedIn() async {
  final store = SecureStore(InMemoryStore());
  final client = ApiClient(store: store);
  final username = uniqueUsername();

  final session = (await AuthRepository(client).signup(
    username: username,
    password: 'a-long-enough-password',
    tncAccepted: true,
  )).valueOrNull!;

  await store.saveTokens(
    accessToken: session.tokens.accessToken,
    refreshToken: session.tokens.refreshToken,
  );
  return Session(username, StoryRepository(client), CommunityRepository(client), client);
}

void main() {
  test('communities are browsable and joinable', () async {
    final me = await signedIn();
    final all = (await me.communities.browse()).valueOrNull!;
    expect(all, isNotEmpty);

    final joined = (await me.communities.setMembership(
      all.first.slug,
      join: true,
    )).valueOrNull!;
    expect(joined.isMember, isTrue);

    final mine = (await me.communities.mine()).valueOrNull!;
    expect(mine.map((item) => item.slug), contains(all.first.slug));
  });

  test('categories filter the browse list', () async {
    final me = await signedIn();
    final filtered = (await me.communities.browse(category: 'job-search')).valueOrNull!;
    expect(filtered, isNotEmpty);
    expect(filtered.every((item) => item.categoryId == 'job-search'), isTrue);
  });

  test('following someone flips the profile state', () async {
    final me = await signedIn();
    final them = await signedIn();

    expect(
      (await me.communities.profile(them.username)).valueOrNull!.isFollowing,
      isFalse,
    );
    await me.communities.setFollow(them.username, follow: true);
    expect(
      (await me.communities.profile(them.username)).valueOrNull!.isFollowing,
      isTrue,
    );
  });

  test('my own profile is marked as mine', () async {
    final me = await signedIn();
    final profile = (await me.communities.profile(me.username)).valueOrNull!;
    expect(profile.isMe, isTrue);
  });

  test('followed authors rank above strangers in the feed', () async {
    final me = await signedIn();
    final friend = await signedIn();
    final stranger = await signedIn();

    final friendStory = (await friend.stories.create(
      body: 'From someone I follow.',
    )).valueOrNull!;
    await friend.stories.publish(friendStory.storyId, visibility: 'public');

    final strangerStory = (await stranger.stories.create(
      body: 'From a stranger, later.',
    )).valueOrNull!;
    await stranger.stories.publish(strangerStory.storyId, visibility: 'public');

    await me.communities.setFollow(friend.username, follow: true);

    final feed = (await me.stories.feed()).valueOrNull!;
    final friendIndex =
        feed.items.indexWhere((item) => item.storyId == friendStory.storyId);
    final strangerIndex =
        feed.items.indexWhere((item) => item.storyId == strangerStory.storyId);

    expect(friendIndex, greaterThanOrEqualTo(0));
    expect(friendIndex, lessThan(strangerIndex));
  });

  test('publishing into a community needs membership', () async {
    final me = await signedIn();
    final slug = (await me.communities.browse()).valueOrNull!.first.slug;
    final draft = (await me.stories.create(body: 'Into the room.')).valueOrNull!;

    final refused = await me.stories.publish(
      draft.storyId,
      visibility: 'public',
      communitySlug: slug,
    );
    expect(refused.failureOrNull!.code, 'NOT_A_MEMBER');

    await me.communities.setMembership(slug, join: true);
    final allowed = await me.stories.publish(
      draft.storyId,
      visibility: 'public',
      communitySlug: slug,
    );
    expect(allowed.isSuccess, isTrue);
  });

  test('a shared story returns a slug url', () async {
    final me = await signedIn();
    final draft = (await me.stories.create(body: 'Pass this on.')).valueOrNull!;
    final published =
        (await me.stories.publish(draft.storyId, visibility: 'public')).valueOrNull!;

    final url = (await me.stories.share(draft.storyId)).valueOrNull!;
    expect(url, endsWith(published.story.slug!));
  });

  test('a private story cannot be shared', () async {
    final me = await signedIn();
    final draft = (await me.stories.create(body: 'Mine only.')).valueOrNull!;
    await me.stories.publish(draft.storyId, visibility: 'private');

    final result = await me.stories.share(draft.storyId);
    expect(result.failureOrNull!.code, 'STORY_NOT_SHAREABLE');
  });

  test('community stories list what was published there', () async {
    final me = await signedIn();
    final slug = (await me.communities.browse()).valueOrNull!.first.slug;
    await me.communities.setMembership(slug, join: true);

    final draft = (await me.stories.create(body: 'Inside the room.')).valueOrNull!;
    await me.stories.publish(
      draft.storyId,
      visibility: 'public',
      communitySlug: slug,
    );

    final page = (await me.communities.stories(slug)).valueOrNull!;
    expect(page.items.map((item) => item.storyId), contains(draft.storyId));
  });
}
