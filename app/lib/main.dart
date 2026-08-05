import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefsStore = await loadPrefsStore();
  final container = ProviderContainer(
    overrides: [prefsStoreProvider.overrideWithValue(prefsStore)],
  );

  unawaited(container.read(authProvider.notifier).restoreSession());

  runApp(
    UncontrolledProviderScope(container: container, child: const StoryApp()),
  );
}
