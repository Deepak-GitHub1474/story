import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/story_text.dart';
import 'package:story_app/theme/app_theme.dart';

Future<void> render(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: StoryText(text: text, fontSize: 16)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('a blank line starts a new paragraph', () {
    final blocks = parseStoryBlocks('One thing.\n\nThen another.');
    expect(blocks.length, 2);
    expect(blocks.every((b) => b.kind == StoryBlockKind.paragraph), isTrue);
  });

  test('a wrapped line stays one paragraph', () {
    final blocks = parseStoryBlocks('I left at\nnineteen.');
    expect(blocks.length, 1);
    expect(blocks.first.text, 'I left at nineteen.');
  });

  test('a bold line on its own is a turn in the story', () {
    final blocks = parseStoryBlocks('**The day I left**\n\nIt rained.');
    expect(blocks.first.kind, StoryBlockKind.heading);
    expect(blocks.first.text, 'The day I left');
  });

  test('dashes become bullets', () {
    final blocks = parseStoryBlocks('- a coat\n- the keys');
    expect(blocks.map((b) => b.kind), everyElement(StoryBlockKind.bullet));
    expect(blocks.map((b) => b.text), ['a coat', 'the keys']);
  });

  test('the plain form carries no marks', () {
    final plain = plainStoryText(
      '**Leaving**\n\n- *her letter*\n\nThen I went.',
    );
    expect(plain.contains('*'), isFalse);
    expect(plain, contains('her letter'));
  });

  testWidgets('no asterisk ever reaches the reader', (tester) async {
    await render(tester, '**Leaving**\n\nI took *her letter*.\n\n- a coat');

    expect(find.textContaining('*'), findsNothing);
    expect(find.text('Leaving'), findsOneWidget);
  });

  testWidgets('bold and italic are shown as weight and slant', (tester) async {
    await render(tester, 'I took **the letter** and *left*.');

    final rich = tester.widget<SelectableText>(
      find.byType(SelectableText).first,
    );
    final spans = rich.textSpan!.children!.cast<TextSpan>();

    expect(
      spans.any((s) => s.style?.fontWeight == FontWeight.w600),
      isTrue,
      reason: 'the bold run should carry weight, not asterisks',
    );
    expect(spans.any((s) => s.style?.fontStyle == FontStyle.italic), isTrue);
  });

  testWidgets('an ordinary story renders exactly as written', (tester) async {
    await render(tester, 'I left at nineteen. Nobody stopped me.');
    expect(find.text('I left at nineteen. Nobody stopped me.'), findsOneWidget);
  });

  test('a line of dashes is kept as a break the writer meant', () {
    final blocks = parseStoryBlocks('Before.\n---\nAfter.');

    expect(blocks.map((b) => b.kind).toList(), [
      StoryBlockKind.paragraph,
      StoryBlockKind.rule,
      StoryBlockKind.paragraph,
    ], reason: 'a writer separating two parts must not lose the separator');
  });

  testWidgets('the break is drawn as a line, not printed as dashes', (
    tester,
  ) async {
    await render(tester, 'Before.\n-------\nAfter.');

    expect(find.byType(Divider), findsOneWidget);
    expect(find.text('-------'), findsNothing);
    expect(find.text('Before.'), findsOneWidget);
    expect(find.text('After.'), findsOneWidget);
  });

  test('symbols a writer types are their own business', () {
    final blocks = parseStoryBlocks('Ask @deepak about the _thing_ - it works.');

    expect(blocks.length, 1);
    expect(blocks.first.text, 'Ask @deepak about the _thing_ - it works.');
    expect(
      plainStoryText('Ask @deepak - #2 & 50% of it.'),
      'Ask @deepak - #2 & 50% of it.',
      reason: 'nothing here is markup, so nothing may be eaten',
    );
  });

  test('a break carries no words into a plain reading', () {
    expect(plainStoryText('Before.\n---\nAfter.'), 'Before. After.');
  });
}
