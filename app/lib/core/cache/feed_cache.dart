import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FeedCache {
  const FeedCache(this._prefs);

  final SharedPreferences _prefs;

  static const _feedKey = 'story.cache.feed';
  static const _stampKey = 'story.cache.feed_at';
  static const maxEntries = 20;
  static const staleAfter = Duration(hours: 6);

  List<Map<String, dynamic>> read() {
    final raw = _prefs.getString(_feedKey);
    if (raw == null) return const [];

    final stamp = _prefs.getInt(_stampKey);
    if (stamp != null) {
      final age = DateTime.now().millisecondsSinceEpoch - stamp;
      if (age > staleAfter.inMilliseconds) return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<Map<String, dynamic>> items) async {
    final trimmed = items.take(maxEntries).toList();
    await _prefs.setString(_feedKey, jsonEncode(trimmed));
    await _prefs.setInt(_stampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    await _prefs.remove(_feedKey);
    await _prefs.remove(_stampKey);
  }
}
