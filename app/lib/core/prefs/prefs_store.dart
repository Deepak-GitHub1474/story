import 'package:shared_preferences/shared_preferences.dart';

class PrefsStore {
  const PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'story.theme';
  static const _readingSizeKey = 'story.reading_size';

  String get theme => _prefs.getString(_themeKey) ?? 'system';

  String get readingSize => _prefs.getString(_readingSizeKey) ?? 'reading';

  Future<void> setTheme(String value) => _prefs.setString(_themeKey, value);

  Future<void> setReadingSize(String value) => _prefs.setString(_readingSizeKey, value);
}
