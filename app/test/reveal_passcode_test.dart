import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_text_field.dart';
import 'package:story_app/theme/app_theme.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: midnightTheme, home: Scaffold(body: child));

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  group('a hidden passcode can be looked at', () {
    testWidgets('it starts hidden', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppTextField(
            controller: TextEditingController(),
            label: 'Vault passcode',
            obscureText: true,
          ),
        ),
      );

      expect(_field(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('tapping the eye shows it, tapping again hides it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppTextField(
            controller: TextEditingController(text: 'rusty gate summer'),
            label: 'Vault passcode',
            obscureText: true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(_field(tester).obscureText, isFalse);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(_field(tester).obscureText, isTrue);
    });

    testWidgets('an ordinary field has no eye', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppTextField(controller: TextEditingController(), label: 'Your name'),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(_field(tester).obscureText, isFalse);
    });

    testWidgets('a field with its own suffix keeps it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppTextField(
            controller: TextEditingController(),
            label: 'Code',
            obscureText: true,
            suffix: const Icon(Icons.timer_outlined),
          ),
        ),
      );

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });
  });
}
