import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/widgets/story_images.dart';
import 'package:story_app/features/stories/widgets/story_post.dart';
import 'package:story_app/theme/app_theme.dart';

/// Most stories in a feed are long enough to be trimmed, and a trimmed card
/// used to swallow every tap. These are the ways in.
Story _card({List<String> images = const []}) => Story(
  storyId: 'st_1',
  slug: 'quiet-steps',
  title: 'Quiet Steps',
  excerpt: 'A short excerpt.',
  body: 'A short excerpt.',
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

Future<int> tapped(WidgetTester tester, Finder target, Story story) async {
  var opens = 0;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryPost(story: story, onTap: () => opens++),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(target, warnIfMissed: false);
  await tester.pumpAndSettle();
  return opens;
}

void main() {
  testWidgets('the picture is a way into the story', (tester) async {
    final story = _card(images: const ['/media/one.jpg']);

    expect(await tapped(tester, find.byType(StoryImages), story), 1);
  });

  testWidgets('a double tap on the picture still only likes it', (
    tester,
  ) async {
    var opens = 0;
    var likes = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: midnightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryPost(
                story: _card(images: const ['/media/one.jpg']),
                onTap: () => opens++,
                onLike: () => likes++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final spot = tester.getCenter(find.byType(StoryImages));
    await tester.tapAt(spot, pointer: 1);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(spot, pointer: 2);
    await tester.pumpAndSettle();

    expect(likes, 1, reason: 'a double tap is a like, the way it always was');
    expect(opens, 0, reason: 'and it must not also open the story');
  });
}
