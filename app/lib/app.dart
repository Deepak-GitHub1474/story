import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/router.dart';
import 'theme/app_theme.dart';

class StoryApp extends ConsumerWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Story',
      debugShowCheckedModeBanner: false,
      theme: paperTheme,
      darkTheme: midnightTheme,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
