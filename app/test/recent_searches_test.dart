import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_app/core/prefs/prefs_store.dart';

Future<PrefsStore> store() async {
  SharedPreferences.setMockInitialValues({});
  return PrefsStore(await SharedPreferences.getInstance());
}

void main() {
  test('there are no recent searches to begin with', () async {
    expect((await store()).recentSearches, isEmpty);
  });

  test('a remembered username comes back', () async {
    final prefs = await store();
    await prefs.rememberSearch('deepak');

    expect(prefs.recentSearches, ['deepak']);
  });

  test('the newest search comes first', () async {
    final prefs = await store();
    await prefs.rememberSearch('one');
    await prefs.rememberSearch('two');

    expect(prefs.recentSearches, ['two', 'one']);
  });

  test('searching the same name twice does not duplicate it', () async {
    final prefs = await store();
    await prefs.rememberSearch('deepak');
    await prefs.rememberSearch('other');
    await prefs.rememberSearch('deepak');

    expect(prefs.recentSearches, ['deepak', 'other']);
  });

  test('only the last eight are kept', () async {
    final prefs = await store();
    for (var index = 0; index < 12; index++) {
      await prefs.rememberSearch('name$index');
    }

    expect(prefs.recentSearches.length, 8);
    expect(prefs.recentSearches.first, 'name11');
  });

  test('a single search can be forgotten', () async {
    final prefs = await store();
    await prefs.rememberSearch('keep');
    await prefs.rememberSearch('drop');
    await prefs.forgetSearch('drop');

    expect(prefs.recentSearches, ['keep']);
  });

  test('all of them can be cleared', () async {
    final prefs = await store();
    await prefs.rememberSearch('one');
    await prefs.rememberSearch('two');
    await prefs.clearSearches();

    expect(prefs.recentSearches, isEmpty);
  });

  test('blank input is not remembered', () async {
    final prefs = await store();
    await prefs.rememberSearch('   ');

    expect(prefs.recentSearches, isEmpty);
  });

  test('searches older than a day are gone', () async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    SharedPreferences.setMockInitialValues({
      'story.recent_searches': ['stale'],
      'story.recent_searches_at': twoDaysAgo.millisecondsSinceEpoch,
    });
    final prefs = PrefsStore(await SharedPreferences.getInstance());

    expect(prefs.recentSearches, isEmpty);
  });

  test('searches from an hour ago survive', () async {
    final anHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    SharedPreferences.setMockInitialValues({
      'story.recent_searches': ['fresh'],
      'story.recent_searches_at': anHourAgo.millisecondsSinceEpoch,
    });
    final prefs = PrefsStore(await SharedPreferences.getInstance());

    expect(prefs.recentSearches, ['fresh']);
  });

  test('remembering something resets the clock', () async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    SharedPreferences.setMockInitialValues({
      'story.recent_searches': ['stale'],
      'story.recent_searches_at': twoDaysAgo.millisecondsSinceEpoch,
    });
    final prefs = PrefsStore(await SharedPreferences.getInstance());

    await prefs.rememberSearch('fresh');

    expect(prefs.recentSearches, ['fresh']);
  });
}
