import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/features/auth/screens/auth_screen.dart';
import 'package:story_app/features/auth/widgets/signin_form.dart';
import 'package:story_app/features/auth/widgets/signup_form.dart';
import 'package:story_app/theme/app_theme.dart';

Future<void> showAuth(
  WidgetTester tester, {
  AuthTab tab = AuthTab.login,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => AuthScreen(initialTab: tab))],
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
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('both ways in live on one screen', (tester) async {
    await showAuth(tester);

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('STORY'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('the sign up tab swaps the form and the wording', (tester) async {
    await showAuth(tester);
    expect(find.text('Referral code (optional)'), findsNothing);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Pick a name nobody can trace back to you.'), findsOneWidget);
    expect(find.text('Referral code (optional)'), findsOneWidget);
    expect(find.text('I accept the Terms & Conditions'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('a deep link opens straight on the sign up tab', (tester) async {
    await showAuth(tester, tab: AuthTab.signup);

    expect(find.text('Referral code (optional)'), findsOneWidget);
  });

  testWidgets('typing survives a trip to the other tab', (tester) async {
    await showAuth(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(SigninForm),
        matching: find.byType(TextField),
      ).first,
      'zebra_owl',
    );
    await tester.pump();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('zebra_owl'), findsOneWidget);
  });

  testWidgets('nothing we did not ask for crept in', (tester) async {
    for (final tab in AuthTab.values) {
      await showAuth(tester, tab: tab);

      for (final stranger in [
        'Continue with Apple',
        'Passkey',
        'Remember me',
        'or continue with',
      ]) {
        expect(find.text(stranger), findsNothing, reason: '$stranger on $tab');
      }
    }
  });

  testWidgets('the action stays pinned on both tabs', (tester) async {
    for (final entry in {AuthTab.login: 'Log in', AuthTab.signup: 'Create account'}.entries) {
      await showAuth(tester, tab: entry.key);

      final button = find
          .descendant(
            of: find.byType(AuthScreen),
            matching: find.widgetWithText(InkWell, entry.value),
          )
          .first;
      expect(
        tester.getBottomLeft(button).dy,
        greaterThan(740),
        reason: '${entry.value} should sit near the floor',
      );
    }
  });

  testWidgets('the tabs sit clear of the artwork', (tester) async {
    await showAuth(tester);

    final bloomBottom = tester.getBottomLeft(find.byType(Image)).dy;
    final tabTop = tester.getTopLeft(find.text('Sign up')).dy;

    expect(
      tabTop,
      greaterThan(bloomBottom),
      reason: 'the bloom overlapped the Sign up tab and its underline',
    );
  });

  testWidgets('neither tab hides anything on an ordinary phone', (
    tester,
  ) async {
    for (final tab in AuthTab.values) {
      await showAuth(tester, tab: tab, size: const Size(390, 800));

      final visible = tab == AuthTab.login
          ? find.byType(SigninForm)
          : find.byType(SignupForm);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(of: visible, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(
        position.maxScrollExtent,
        0,
        reason: 'the $tab form should need no scrolling',
      );
    }
  });

  testWidgets('a small phone with big type still lays out', (tester) async {
    for (final tab in AuthTab.values) {
      await showAuth(
        tester,
        tab: tab,
        size: const Size(320, 560),
        textScale: 2,
      );
    }
  });
}
