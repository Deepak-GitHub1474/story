import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_sheet.dart';
import 'package:story_app/features/auth/widgets/terms_checkbox.dart';
import 'package:story_app/theme/app_theme.dart';

Widget _host(void Function(BuildContext) onTap) => MaterialApp(
  theme: midnightTheme,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => onTap(context),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('the terms open in a sheet the reader can drag', (tester) async {
    await tester.pumpWidget(_host(showTermsSheet));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.minChildSize, lessThan(sheet.initialChildSize));
    expect(sheet.maxChildSize, greaterThan(sheet.initialChildSize));
    expect(
      sheet.shouldCloseOnMinExtent,
      isTrue,
      reason: 'dragging it all the way down should close it',
    );
  });

  testWidgets('dragging the terms down closes them', (tester) async {
    await tester.pumpWidget(_host(showTermsSheet));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Terms & Conditions'), findsOneWidget);

    await tester.drag(find.text('You stay anonymous'), const Offset(0, 900));
    await tester.pumpAndSettle();

    expect(find.text('Terms & Conditions'), findsNothing);
  });

  testWidgets('every promise we make is listed', (tester) async {
    await tester.pumpWidget(_host(showTermsSheet));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('You stay anonymous'), findsOneWidget);
    expect(find.text('Your password cannot be recovered'), findsOneWidget);
    expect(
      find.text('Your vault opens with its passcode alone'),
      findsOneWidget,
    );
  });

  testWidgets('an ordinary menu sheet is not draggable', (tester) async {
    await tester.pumpWidget(
      _host(
        (context) => showAppSheet<void>(
          context: context,
          title: 'Pick one',
          builder: (_) => const Text('an option'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('an option'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });
}
