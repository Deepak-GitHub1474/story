import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/expandable_text.dart';
import 'package:story_app/components/text_measure.dart';
import 'package:story_app/theme/app_theme.dart';

const _style = TextStyle(fontSize: 14, height: 1.5);

TextSpan words(int count) =>
    TextSpan(text: List.filled(count, 'word').join(' '), style: _style);

Future<void> showText(
  WidgetTester tester,
  TextSpan span, {
  required double cap,
  ValueChanged<TextSpan>? onTooLong,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: ExpandableText(
            text: span,
            maxExpandedHeight: cap,
            onTooLong: onTooLong,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('measuring before deciding', () {
    test('a couple of lines does not need its own room', () {
      expect(
        longerThanLines(
          span: words(8),
          width: 300,
          lines: 10,
          direction: TextDirection.ltr,
        ),
        isFalse,
      );
    });

    test('a wall of text does', () {
      expect(
        longerThanLines(
          span: words(600),
          width: 300,
          lines: 10,
          direction: TextDirection.ltr,
        ),
        isTrue,
      );
    });

    test('a width of nothing decides nothing', () {
      expect(
        longerThanLines(
          span: words(600),
          width: 0,
          lines: 10,
          direction: TextDirection.ltr,
        ),
        isFalse,
        reason: 'before the first layout there is nothing to measure against',
      );
    });

    test('the line count is what decides, not the height of the screen', () {
      expect(
        longerThanLines(
          span: words(60),
          width: 300,
          lines: 10,
          direction: TextDirection.ltr,
        ),
        isTrue,
        reason: 'a dozen lines is a read, not a caption',
      );
    });
  });

  group('what more does', () {
    testWidgets('a short story still opens in place', (tester) async {
      final asked = <TextSpan>[];
      await showText(tester, words(30), cap: 400, onTooLong: asked.add);

      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      expect(asked, isEmpty, reason: 'it fits, so it expands where it is');
      expect(find.text('less'), findsOneWidget);
    });

    testWidgets('a long story asks for a room of its own', (tester) async {
      final asked = <TextSpan>[];
      await showText(tester, words(800), cap: 200, onTooLong: asked.add);

      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      expect(asked, hasLength(1));
      expect(
        find.text('less'),
        findsNothing,
        reason: 'it never expanded in place, so there is nothing to collapse',
      );
    });

    testWidgets('with nowhere to send it, it expands as it always did', (
      tester,
    ) async {
      await showText(tester, words(800), cap: 200);

      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      expect(find.text('less'), findsOneWidget);
    });

    testWidgets('text fetched on demand is measured, not the excerpt', (
      tester,
    ) async {
      final asked = <TextSpan>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: midnightTheme,
          home: Scaffold(
            body: SizedBox(width: 300, child: _LateText(onTooLong: asked.add)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      expect(
        asked,
        hasLength(1),
        reason: 'the whole story arrives after the tap and it is the long one',
      );
    });

    testWidgets('a story that fits in three lines offers no more at all', (
      tester,
    ) async {
      final asked = <TextSpan>[];
      await showText(tester, words(6), cap: 200, onTooLong: asked.add);

      expect(find.text('more'), findsNothing);
      expect(asked, isEmpty);
    });
  });
}

class _LateText extends StatefulWidget {
  const _LateText({required this.onTooLong});

  final ValueChanged<TextSpan> onTooLong;

  @override
  State<_LateText> createState() => _LateTextState();
}

class _LateTextState extends State<_LateText> {
  TextSpan? _whole;

  @override
  Widget build(BuildContext context) => ExpandableText(
    text: words(40),
    expandedText: _whole,
    maxExpandedHeight: 200,
    onTooLong: widget.onTooLong,
    onExpand: () async {
      setState(() => _whole = words(800));
      return _whole;
    },
  );
}
