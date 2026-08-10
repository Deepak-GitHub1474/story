import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/providers/theme_provider.dart';
import 'routing/router.dart';
import 'theme/app_theme.dart';
import 'core/session/forget_session.dart';

class StoryApp extends ConsumerWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionGuardProvider);

    ref.watch(themeProvider);
    final mode = ref.read(themeProvider.notifier).mode;

    return MaterialApp.router(
      title: 'Story',
      debugShowCheckedModeBanner: false,
      theme: paperTheme,
      darkTheme: midnightTheme,
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
