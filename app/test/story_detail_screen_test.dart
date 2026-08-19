import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_app/core/prefs/prefs_store.dart';
import 'package:story_app/features/settings/providers/theme_provider.dart';
import 'package:story_app/features/auth/providers/auth_provider.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/screens/story_detail_screen.dart';
import 'package:story_app/features/stories/widgets/story_article.dart';
import 'package:story_app/features/stories/widgets/story_images.dart';
import 'package:story_app/theme/app_theme.dart';

import 'comments_sheet_test.dart' show FakeAuth, FakeComments;

Story _story({List<String> images = const ['/media/one.jpg']}) => Story(
  storyId: 'st_1',
  slug: 'quiet-steps',
  title: 'Quiet Steps',
  excerpt: 'An excerpt',
  body: '**A heading**\n\nThe body of the story goes here.',
  visibility: 'public',
  images: images,
  publishedAt: '2026-08-14T03:00:00.000Z',
  createdAt: '2026-08-14T03:00:00.000Z',
  updatedAt: '2026-08-14T03:00:00.000Z',
  readingMinutes: 2,
  likes: 3,
  comments: 0,
  isLiked: false,
  author: const StoryAuthor(
    userId: 'us_1',
    username: 'deepak',
    displayName: 'deepak',
    avatarSeed: 'seed',
  ),
);

Future<void> showScreen(WidgetTester tester, {Story? story}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PrefsStore(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => FakeAuth('us_me')),
        commentsProvider.overrideWith(() => FakeComments(const [])),
        storyDetailProvider(
          'st_1',
        ).overrideWith((ref) async => story ?? _story()),
      ],
      child: MaterialApp(
        theme: midnightTheme,
        home: const StoryDetailScreen(storyId: 'st_1'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the screen a notification opens still renders the story', (
    tester,
  ) async {
    await showScreen(tester);

    expect(find.text('Quiet Steps'), findsOneWidget);
    expect(find.byType(StoryArticle), findsOneWidget);
    expect(find.text('deepak'), findsWidgets, reason: 'the author is named');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.textSpan?.toPlainText() ?? '').contains(
              'body of the story',
            ),
      ),
      findsOneWidget,
      reason: 'the words are the point of the screen',
    );
  });

  testWidgets('the picture is above the words here too', (tester) async {
    await showScreen(tester);

    final image = tester.getTopLeft(find.byType(StoryImages)).dy;
    final title = tester.getTopLeft(find.text('Quiet Steps')).dy;

    expect(image, lessThan(title));
  });

  testWidgets('a story with no picture still opens', (tester) async {
    await showScreen(tester, story: _story(images: const []));

    expect(find.text('Quiet Steps'), findsOneWidget);
    expect(find.byType(StoryImages), findsNothing);
  });
}
