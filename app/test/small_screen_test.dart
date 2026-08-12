import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/features/auth/screens/signin_screen.dart';
import 'package:story_app/features/auth/screens/signup_screen.dart';
import 'package:story_app/features/auth/screens/welcome_screen.dart';
import 'package:story_app/theme/app_theme.dart';

Future<void> show(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: midnightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final screens = {
    'welcome': const WelcomeScreen(),
    'signing up': const SignupScreen(),
    'signing in': const SigninScreen(),
  };

  group('nothing spills off a small screen', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits a short phone', (tester) async {
        await show(
          tester,
          entry.value,
          size: const Size(360, 640),
          textScale: 1,
        );
      });

      testWidgets('${entry.key} survives larger type', (tester) async {
        await show(
          tester,
          entry.value,
          size: const Size(360, 640),
          textScale: 1.5,
        );
      });

      testWidgets('${entry.key} survives a tiny phone and huge type', (
        tester,
      ) async {
        await show(
          tester,
          entry.value,
          size: const Size(320, 560),
          textScale: 2,
        );
      });
    }
  });

  testWidgets('the welcome words clear the artwork', (tester) async {
    await show(
      tester,
      const WelcomeScreen(),
      size: const Size(400, 1000),
      textScale: 1,
    );

    final headline = tester.getTopLeft(find.text('STORY')).dy;
    expect(headline, lessThan(120), reason: 'the wordmark sits near the top');
    expect(find.text('Private by design'), findsOneWidget);
    expect(find.text('I already have one'), findsOneWidget);
  });
}
