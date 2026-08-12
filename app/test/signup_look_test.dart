import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/features/auth/screens/signup_screen.dart';
import 'package:story_app/features/auth/widgets/password_strength_bar.dart';
import 'package:story_app/features/auth/widgets/terms_checkbox.dart';
import 'package:story_app/theme/app_theme.dart';

void main() {
  for (final entry in {
    'maroon': maroonTheme,
    'blush': blushTheme,
    'paper': paperTheme,
    'midnight': midnightTheme,
  }.entries) {
    testWidgets('creating an account looks right on ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SignupScreen())],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: entry.value,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Your privacy is our priority.'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(find.byIcon(Icons.card_giftcard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

    });
  }

  testWidgets('the strength bar and the terms box are still there', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SignupScreen())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: maroonTheme,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PasswordStrengthBar), findsOneWidget);
    expect(find.byType(TermsCheckbox), findsOneWidget);
  });
}
