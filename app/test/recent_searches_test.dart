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
}
