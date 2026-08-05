@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/api/endpoints.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/auth/data/auth_repository.dart';
import 'package:story_app/features/auth/data/profile_repository.dart';
import 'package:story_app/features/stories/data/story_repository.dart';

String uniqueUsername() =>
    'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

class Session {
  Session(this.username, this.client, this.stories, this.profile);

  final String username;
  final ApiClient client;
  final StoryRepository stories;
  final ProfileRepository profile;
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
  return Session(username, client, StoryRepository(client), ProfileRepository(client));
}

Future<bool> report(
  Session session, {
  required String kind,
  required String id,
  String reason = 'spam',
}) async {
  final result = await session.client.post<bool>(
    Endpoints.reports,
    body: {'target_kind': kind, 'target_id': id, 'reason': reason},
    parse: (data) => data['reported'] as bool? ?? true,
  );
  return result.isSuccess;
}

void main() {
  test('a story can be reported', () async {
    final author = await signedIn();
    final draft = (await author.stories.create(body: 'Report me.')).valueOrNull!;
    await author.stories.publish(draft.storyId, visibility: 'public');

    final reader = await signedIn();
    expect(await report(reader, kind: 'story', id: draft.storyId), isTrue);
  });

  test('reporting your own story is refused', () async {
    final author = await signedIn();
    final draft = (await author.stories.create(body: 'My own words.')).valueOrNull!;
    await author.stories.publish(draft.storyId, visibility: 'public');

    final result = await author.client.post<bool>(
      Endpoints.reports,
      body: {
        'target_kind': 'story',
        'target_id': draft.storyId,
        'reason': 'spam',
      },
      parse: (data) => true,
    );
    expect(result.failureOrNull!.code, 'SELF_REPORT');
  });

  test('a user can be reported', () async {
    final target = await signedIn();
    final reader = await signedIn();
    expect(
      await report(reader, kind: 'user', id: target.username, reason: 'impersonation'),
      isTrue,
    );
  });

  test('turning notifications off stops them arriving', () async {
    final me = await signedIn();
    await me.profile.updateProfile(prefs: {'notify_in_app': false});

    final draft = (await me.stories.create(body: 'Quiet please.')).valueOrNull!;
    await me.stories.publish(draft.storyId, visibility: 'public');

    final other = await signedIn();
    await other.stories.setLike(draft.storyId, liked: true);

    final notifications = await me.client.get<int>(
      Endpoints.unreadCount,
      parse: (data) => data['unread'] as int,
    );
    expect(notifications.valueOrNull, 0);
  });

  test('notifications arrive when left on', () async {
    final me = await signedIn();
    final draft = (await me.stories.create(body: 'Tell me.')).valueOrNull!;
    await me.stories.publish(draft.storyId, visibility: 'public');

    final other = await signedIn();
    await other.stories.setLike(draft.storyId, liked: true);

    final notifications = await me.client.get<int>(
      Endpoints.unreadCount,
      parse: (data) => data['unread'] as int,
    );
    expect(notifications.valueOrNull, 1);
  });
}
