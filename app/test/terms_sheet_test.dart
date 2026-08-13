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

  testWidgets('the terms follow the finger instead of jumping to stops', (
    tester,
  ) async {
    await tester.pumpWidget(_host(showTermsSheet));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(
      sheet.snap,
      isFalse,
      reason: 'snapping is what makes it feel like three fixed heights',
    );
    expect(sheet.snapSizes, isNull);
    expect(sheet.maxChildSize, 1);
  });

  testWidgets('a half drag leaves the terms at a height of their own', (
    tester,
  ) async {
    await tester.pumpWidget(_host(showTermsSheet));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final before = tester.getTopLeft(find.byType(DraggableScrollableSheet)).dy;
    final sheetHeightBefore = tester
        .getSize(find.byType(DraggableScrollableSheet))
        .height;

    await tester.drag(find.text('You stay anonymous'), const Offset(0, -120));
    await tester.pumpAndSettle();

    final grown = tester.getSize(find.byType(DraggableScrollableSheet)).height;
    expect(
      grown,
      greaterThan(sheetHeightBefore),
      reason: 'dragging up should grow the sheet',
    );
    expect(before, isNotNull);
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

  testWidgets('a titled sheet rules a line under its title', (tester) async {
    await tester.pumpWidget(_host(showTermsSheet));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rule = tester.widget<Divider>(find.byType(Divider).first);
    expect(rule.thickness, 0.5);
    expect(
      rule.color!.a,
      lessThan(1),
      reason: 'the rule should be lighter than the border it comes from',
    );

    final titleBottom = tester
        .getBottomLeft(find.text('Terms & Conditions'))
        .dy;
    expect(
      tester.getTopLeft(find.byType(Divider).first).dy,
      greaterThan(titleBottom),
    );
  });

  testWidgets('every sheet indents its content the same way', (tester) async {
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

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    final padding = scroll.padding as EdgeInsets;
    expect(padding.left, 16);
    expect(padding.right, 16);
    expect(padding.top, 12);
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
