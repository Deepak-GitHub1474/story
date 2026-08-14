import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_card.dart';
import 'package:story_app/components/app_sheet.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

Future<void> openSheet(
  WidgetTester tester, {
  required WidgetBuilder builder,
  String title = 'A sheet',
  bool isResizable = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context: context,
              title: title,
              isResizable: isResizable,
              builder: builder,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every sheet titles itself the same way', (tester) async {
    for (final title in ['Share', 'Comments', 'Likes']) {
      await openSheet(
        tester,
        title: title,
        builder: (_) => const SizedBox(height: 80),
      );

      final style = tester.widget<Text>(find.text(title)).style!;
      expect(style.fontSize, AppTypeScale.heading, reason: title);
      expect(style.fontWeight, FontWeight.w500, reason: title);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('plain content sits at the shared inset', (tester) async {
    await openSheet(tester, builder: (_) => const SizedBox(height: 40));

    final padding =
        tester
                .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
                .padding
            as EdgeInsets;

    expect(padding.left, AppSheet.insets.left);
    expect(padding.right, AppSheet.insets.right);
    expect(padding.top, AppSheet.insets.top);
  });

  testWidgets('a list of choices starts where plain content starts', (
    tester,
  ) async {
    await openSheet(
      tester,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ListTile(title: Text('Add to your story', key: Key('option'))),
        ],
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const Key('option'))).dx,
      tester.getTopLeft(find.byType(ListTile)).dx,
      reason: 'a ListTile must not add its own 16 on top of the sheet inset',
    );
  });

  testWidgets('a row that carries its own inset is not inset twice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                title: 'Themes',
                contentPadding: const EdgeInsets.only(top: AppSpacing.md),
                builder: (_) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [AppListRow(label: 'System')],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fromSheetEdge =
        tester.getTopLeft(find.text('System')).dx -
        tester.getTopLeft(find.byType(AppSheet)).dx;

    expect(
      fromSheetEdge,
      AppSpacing.lg,
      reason: 'AppListRow already pads itself, so the sheet must not pad again',
    );
  });

  testWidgets('the sheet is told how far it may be dragged', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                title: 'Comments',
                isResizable: true,
                initialSize: 0.5,
                minSize: 0.3,
                maxSize: 0.9,
                builder: (_) => const SizedBox(height: 400),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.initialChildSize, 0.5);
    expect(sheet.minChildSize, 0.3);
    expect(sheet.maxChildSize, 0.9);
  });

  testWidgets('a caller can own the scrolling and keep the same chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: AppSheet(
            title: 'Comments',
            body: ListView(
              padding: AppSheet.insets,
              children: const [Text('first', key: Key('first'))],
            ),
            footer: const Text('composer'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(const Key('first'))).dx, AppSpacing.lg);
    expect(find.text('composer'), findsOneWidget);
    final style = tester.widget<Text>(find.text('Comments')).style!;
    expect(style.fontSize, AppTypeScale.heading);
  });
}
