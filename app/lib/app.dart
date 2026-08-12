import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final chosen = ref.watch(themeProvider);
    final mode = ref.read(themeProvider.notifier).mode;
    final fixed = fixedThemeFor(chosen);

    return MaterialApp.router(
      title: 'Story',
      debugShowCheckedModeBanner: false,
      theme: fixed ?? paperTheme,
      darkTheme: fixed ?? midnightTheme,
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final colors = context.colors;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: colors.surface,
            systemNavigationBarDividerColor: colors.border,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
