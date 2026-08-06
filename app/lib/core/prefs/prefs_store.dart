import 'package:shared_preferences/shared_preferences.dart';

class PrefsStore {
  const PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'story.theme';
  static const _readingSizeKey = 'story.reading_size';
  static const _recentSearchKey = 'story.recent_searches';
  static const _recentSearchStampKey = 'story.recent_searches_at';
  static const recentSearchLimit = 8;
  static const recentSearchLifetime = Duration(days: 1);

  String get theme => _prefs.getString(_themeKey) ?? 'system';

  String get readingSize => _prefs.getString(_readingSizeKey) ?? 'reading';

  Future<void> setTheme(String value) => _prefs.setString(_themeKey, value);

  Future<void> setReadingSize(String value) => _prefs.setString(_readingSizeKey, value);

  List<String> get recentSearches {
    final stamp = _prefs.getInt(_recentSearchStampKey);
    if (stamp == null) return _prefs.getStringList(_recentSearchKey) ?? const [];

    final age = DateTime.now().millisecondsSinceEpoch - stamp;
    if (age > recentSearchLifetime.inMilliseconds) return const [];

    return _prefs.getStringList(_recentSearchKey) ?? const [];
  }

  Future<void> rememberSearch(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    final next = [trimmed, ...recentSearches.where((item) => item != trimmed)];
    await _prefs.setStringList(
      _recentSearchKey,
      next.take(recentSearchLimit).toList(),
    );
    await _prefs.setInt(
      _recentSearchStampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> forgetSearch(String username) => _prefs.setStringList(
    _recentSearchKey,
    recentSearches.where((item) => item != username).toList(),
  );

  Future<void> clearSearches() async {
    await _prefs.remove(_recentSearchKey);
    await _prefs.remove(_recentSearchStampKey);
  }
}
