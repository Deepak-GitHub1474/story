import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_app/core/cache/feed_cache.dart';
import 'package:story_app/core/session/forget_session.dart';
import 'package:story_app/features/chat/providers/chat_providers.dart';
import 'package:story_app/features/notifications/providers/notification_providers.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/vault/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nothing that holds one account\'s data is left off the list', () {
    for (final provider in [
      feedProvider,
      myStoriesProvider,
      storyDetailProvider,
      commentsProvider,
      notificationsProvider,
      unreadCountProvider,
      conversationsProvider,
      chatUnreadProvider,
      chatIdentityProvider,
      vaultItemsProvider,
      vaultOverviewProvider,
    ]) {
      expect(
        userScopedProviders,
        contains(provider),
        reason: 'this provider would carry data into the next account',
      );
    }
  });

  test('the list has no duplicates', () {
    expect(userScopedProviders.toSet().length, userScopedProviders.length);
  });

  test('the cached feed can be wiped from disk', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = FeedCache(await SharedPreferences.getInstance());

    await cache.write([
      {'story_id': 'sto_private', 'body': 'not for the next person'},
    ]);
    expect(cache.read(), isNotEmpty);

    await cache.clear();

    expect(cache.read(), isEmpty);
  });

  test('a cached feed older than the window is never served', () async {
    SharedPreferences.setMockInitialValues({
      'story.cache.feed': '[{"story_id":"sto_old"}]',
      'story.cache.feed_at': DateTime.now()
          .subtract(const Duration(hours: 7))
          .millisecondsSinceEpoch,
    });

    final cache = FeedCache(await SharedPreferences.getInstance());

    expect(cache.read(), isEmpty);
  });
}
