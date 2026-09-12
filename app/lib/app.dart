import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_taps.dart';
import 'features/calls/data/call_session.dart';
import 'features/calls/providers/call_providers.dart';
import 'features/settings/providers/theme_provider.dart';
import 'routing/router.dart';
import 'routing/routes.dart';
import 'theme/app_theme.dart';
import 'core/session/forget_session.dart';

class StoryApp extends ConsumerStatefulWidget {
  const StoryApp({super.key});

  @override
  ConsumerState<StoryApp> createState() => _StoryAppState();
}

class _StoryAppState extends ConsumerState<StoryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(callControllerProvider.notifier).checkRinging();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionGuardProvider);
    ref.watch(pushTapsProvider);

    ref.listen<CallSession?>(callControllerProvider, (previous, next) {
      if (previous != null || next == null) return;
      if (!next.isIncoming) return;
      ref.read(routerProvider).push(Routes.call);
    });

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
            systemNavigationBarColor: colors.bg,
            systemNavigationBarDividerColor: Colors.transparent,
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
