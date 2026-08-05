import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_app/core/cache/feed_cache.dart';

Map<String, dynamic> story(String id) => {
  'story_id': id,
  'author': {'display_name': 'Someone', 'avatar_seed': 'abc'},
  'excerpt': 'An excerpt',
  'visibility': 'public',
  'counts': {'likes': 0, 'comments': 0},
  'created_at': '2026-08-05T00:00:00.000Z',
  'updated_at': '2026-08-05T00:00:00.000Z',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FeedCache> build() async =>
      FeedCache(await SharedPreferences.getInstance());

  test('returns nothing when no feed was ever cached', () async {
    expect((await build()).read(), isEmpty);
  });

  test('round trips what it wrote', () async {
    final cache = await build();
    await cache.write([story('sto_1'), story('sto_2')]);
    expect(cache.read().map((item) => item['story_id']), ['sto_1', 'sto_2']);
  });

  test('caps how many entries it keeps', () async {
    final cache = await build();
    await cache.write([for (var i = 0; i < 40; i++) story('sto_$i')]);
    expect(cache.read().length, FeedCache.maxEntries);
  });

  test('drops the cache once it is stale', () async {
    final old = DateTime.now()
        .subtract(FeedCache.staleAfter + const Duration(minutes: 1))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'story.cache.feed': jsonEncode([story('sto_1')]),
      'story.cache.feed_at': old,
    });

    expect((await build()).read(), isEmpty);
  });

  test('keeps a cache that is still fresh', () async {
    SharedPreferences.setMockInitialValues({
      'story.cache.feed': jsonEncode([story('sto_1')]),
      'story.cache.feed_at': DateTime.now().millisecondsSinceEpoch,
    });

    expect((await build()).read().length, 1);
  });

  test('survives corrupted json instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      'story.cache.feed': 'not json at all',
      'story.cache.feed_at': DateTime.now().millisecondsSinceEpoch,
    });

    expect((await build()).read(), isEmpty);
  });

  test('clearing removes everything', () async {
    final cache = await build();
    await cache.write([story('sto_1')]);
    await cache.clear();
    expect(cache.read(), isEmpty);
  });
}
