import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/push/push_routes.dart';

void main() {
  test('a message opens that conversation, not the inbox', () {
    final route = routeForPush({
      'kind': 'chat_message',
      'target_kind': 'conversation',
      'target_id': 'cnv_01KZNC2XBTD3F1259XT4TQP8WW',
    });

    expect(route, '/chat/cnv_01KZNC2XBTD3F1259XT4TQP8WW');
  });

  test('a like opens the story it was about', () {
    final route = routeForPush({
      'kind': 'story_like',
      'target_kind': 'story',
      'target_id': 'sto_123',
    });

    expect(route, '/story/sto_123');
  });

  test('a comment opens the story too', () {
    expect(
      routeForPush({
        'kind': 'story_comment',
        'target_kind': 'story',
        'target_id': 'sto_9',
      }),
      '/story/sto_9',
    );
  });

  test('a new follower opens their profile', () {
    final route = routeForPush({
      'kind': 'new_follower',
      'target_kind': 'user',
      'target_id': 'usr_1',
      'username': 'riverbend',
    });

    expect(
      route,
      '/u/riverbend',
      reason: 'the route needs the name, not the id',
    );
  });

  test('a follower with no name falls back to the activity list', () {
    expect(
      routeForPush({'target_kind': 'user', 'target_id': 'usr_1'}),
      '/activity',
    );
  });

  test('a kind we do not know yet still opens something useful', () {
    expect(
      routeForPush({'kind': 'invented_later', 'target_kind': 'mystery'}),
      '/activity',
      reason: 'a future notification kind must not dead-end on the feed screen',
    );
  });

  test('an empty conversation id opens the inbox rather than a broken route', () {
    expect(
      routeForPush({'target_kind': 'conversation', 'target_id': ''}),
      '/chats',
    );
  });

  test('nothing at all routes nowhere', () {
    expect(routeForPush({}), isNull);
  });
}
