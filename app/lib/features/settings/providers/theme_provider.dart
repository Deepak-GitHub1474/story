import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_store.dart';

final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => throw UnimplementedError('PrefsStore must be overridden at startup'),
);

final themeProvider = NotifierProvider<ThemeNotifier, String>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<String> {
  @override
  String build() => ref.read(prefsStoreProvider).theme;

  Future<void> select(String value) async {
    state = value;
    await ref.read(prefsStoreProvider).setTheme(value);
  }

  ThemeMode get mode => switch (state) {
    'midnight' => ThemeMode.dark,
    'paper' => ThemeMode.light,
    _ => ThemeMode.system,
  };
}

final readingSizeProvider = NotifierProvider<ReadingSizeNotifier, String>(
  ReadingSizeNotifier.new,
);

class ReadingSizeNotifier extends Notifier<String> {
  @override
  String build() => ref.read(prefsStoreProvider).readingSize;

  Future<void> select(String value) async {
    state = value;
    await ref.read(prefsStoreProvider).setReadingSize(value);
  }
}

Future<PrefsStore> loadPrefsStore() async =>
    PrefsStore(await SharedPreferences.getInstance());
