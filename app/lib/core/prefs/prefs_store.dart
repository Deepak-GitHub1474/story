import 'package:shared_preferences/shared_preferences.dart';

class PrefsStore {
  const PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'story.theme';
  static const _readingSizeKey = 'story.reading_size';
  static const _recentSearchKey = 'story.recent_searches';
  static const recentSearchLimit = 8;

  String get theme => _prefs.getString(_themeKey) ?? 'system';

  String get readingSize => _prefs.getString(_readingSizeKey) ?? 'reading';

  Future<void> setTheme(String value) => _prefs.setString(_themeKey, value);

  Future<void> setReadingSize(String value) => _prefs.setString(_readingSizeKey, value);

  List<String> get recentSearches => _prefs.getStringList(_recentSearchKey) ?? const [];

  Future<void> rememberSearch(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    final next = [trimmed, ...recentSearches.where((item) => item != trimmed)];
    await _prefs.setStringList(
      _recentSearchKey,
      next.take(recentSearchLimit).toList(),
    );
  }

  Future<void> forgetSearch(String username) => _prefs.setStringList(
    _recentSearchKey,
    recentSearches.where((item) => item != username).toList(),
  );

  Future<void> clearSearches() => _prefs.remove(_recentSearchKey);
}
