import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/auth/screens/signin_screen.dart';
import 'package:story_app/features/auth/screens/signup_screen.dart';
import 'package:story_app/features/auth/screens/welcome_screen.dart';

import 'small_screen_test.dart' show show;

double extentOf(WidgetTester tester) {
  final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
  return scrollable.controller?.position.maxScrollExtent ??
      Scrollable.of(
        tester.element(find.byType(Scrollable).first),
      ).position.maxScrollExtent;
}

void main() {
  final screens = {
    'welcome': const WelcomeScreen(),
    'signing up': const SignupScreen(),
    'signing in': const SigninScreen(),
  };

  final phones = {
    'a tall phone': const Size(393, 852),
    'an average phone': const Size(390, 800),
  };

  group('an ordinary phone shows everything at once', () {
    for (final screen in screens.entries) {
      for (final phone in phones.entries) {
        testWidgets('${screen.key} needs no scrolling on ${phone.key}', (
          tester,
        ) async {
          await show(tester, screen.value, size: phone.value, textScale: 1);

          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;

          expect(
            position.maxScrollExtent,
            0,
            reason: 'nothing should be hidden below the fold',
          );
        });
      }
    }
  });
}
