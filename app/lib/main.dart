import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/cache/feed_cache.dart';
import 'core/prefs/prefs_store.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
      feedCacheProvider.overrideWithValue(FeedCache(prefs)),
    ],
  );

  unawaited(container.read(authProvider.notifier).restoreSession());

  runApp(
    UncontrolledProviderScope(container: container, child: const StoryApp()),
  );
}
