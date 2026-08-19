import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/widgets/story_article.dart';
import 'package:story_app/features/stories/widgets/story_images.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

Story _story({List<String> images = const [], String? title = 'Quiet Steps'}) =>
    Story(
      storyId: 'st_1',
      slug: 'quiet-steps',
      title: title,
      excerpt: 'An excerpt',
      body: '**A heading**\n\nThe body of the story goes here.',
      visibility: 'public',
      images: images,
      publishedAt: '2026-08-14T03:00:00.000Z',
      createdAt: '2026-08-14T03:00:00.000Z',
      updatedAt: '2026-08-14T03:00:00.000Z',
      readingMinutes: 2,
      likes: 0,
      comments: 0,
      isLiked: false,
      author: const StoryAuthor(
        userId: 'us_1',
        username: 'deepak',
        displayName: 'deepak',
        avatarSeed: 'seed',
      ),
    );

Future<void> show(WidgetTester tester, Story story) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StoryArticle(story: story, bodySize: AppTypeScale.reading),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder textWith(String needle) => find.byWidgetPredicate(
  (widget) =>
      widget is SelectableText &&
      (widget.textSpan?.toPlainText() ?? '').contains(needle),
);

void main() {
  testWidgets('the picture comes before the words', (tester) async {
    await show(tester, _story(images: const ['/media/one.jpg']));

    final image = tester.getTopLeft(find.byType(StoryImages)).dy;
    final title = tester.getTopLeft(find.text('Quiet Steps')).dy;
    final body = tester.getTopLeft(textWith('body of the story')).dy;

    expect(image, lessThan(title), reason: 'the card showed it first too');
    expect(title, lessThan(body));
  });

  testWidgets('a story with no picture leaves no gap where one would be', (
    tester,
  ) async {
    await show(tester, _story());

    expect(find.byType(StoryImages), findsNothing);
  });

  testWidgets('the title is a heading, not a billboard', (tester) async {
    await show(tester, _story());

    final title = tester.widget<Text>(find.text('Quiet Steps'));

    expect(
      title.style?.fontSize,
      AppTypeScale.heading,
      reason: 'the card it was tapped from sets its title at 14',
    );
  });

  testWidgets('a story with no title shows none', (tester) async {
    await show(tester, _story(title: null));

    expect(find.text('Quiet Steps'), findsNothing);
    expect(textWith('body of the story'), findsOneWidget);
  });

  testWidgets('the markup is read, never shown', (tester) async {
    await show(tester, _story());

    expect(textWith('A heading'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });
}
