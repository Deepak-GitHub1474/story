import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_sheet.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/widgets/story_post.dart';
import 'package:story_app/theme/app_theme.dart';

const _opening =
    'I never had the kind of story people write books about. There was no '
    'sudden lightning strike of genius, no dramatic inheritance, and no moment '
    'where I looked out over a vast empire I had built from the dust. ';

final _middling =
    '$_opening**The turn came quietly.** I started with empty pockets and a '
    'borrowed desk, and every ordinary morning after that asked the same '
    'small question of me.';

final _whole =
    '$_opening**The turn came quietly.** I started with empty pockets and a '
    'borrowed desk, and every ordinary morning after that one asked the same '
    'small question of me: will you sit down again today? '
    '${'The answer was usually yes, and that was the whole secret. ' * 8}';

Story _card({String? body}) => Story(
  storyId: 'st_full',
  slug: 'quiet-steps',
  title: 'Quiet Steps on Ordinary Ground',
  excerpt: '${_opening.substring(0, 200)}…',
  body: body,
  visibility: 'public',
  publishedAt: DateTime.now().toUtc().toIso8601String(),
  createdAt: DateTime.now().toUtc().toIso8601String(),
  updatedAt: DateTime.now().toUtc().toIso8601String(),
  readingMinutes: 4,
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

Finder richTextWith(String needle) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(needle),
);

Future<void> showCard(
  WidgetTester tester, {
  Story? story,
  Story? served,
  int fetches = 0,
  VoidCallback? onOpen,
}) async {
  final card = story ?? _card();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (served != null)
          storyDetailProvider(card.storyId).overrideWith((ref) async => served),
      ],
      child: MaterialApp(
        theme: midnightTheme,
        home: Scaffold(body: StoryPost(story: card, onTap: onOpen)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the card offers to open the rest of a trimmed story', (
    tester,
  ) async {
    await showCard(tester);

    expect(find.text('more'), findsOneWidget);
    expect(richTextWith('empty pockets'), findsNothing);
  });

  testWidgets('tapping more brings back everything that was written', (
    tester,
  ) async {
    await showCard(tester, served: _card(body: _middling));

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    expect(
      richTextWith('borrowed desk'),
      findsOneWidget,
      reason: 'the reader asked for the whole thing, not the first 240 letters',
    );
    expect(
      richTextWith('small question'),
      findsOneWidget,
      reason: 'the tail of the story must survive',
    );
  });

  testWidgets('the markup never reaches the reader as asterisks', (
    tester,
  ) async {
    await showCard(tester, served: _card(body: _middling));

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    expect(richTextWith('The turn came quietly.'), findsOneWidget);
    expect(richTextWith('**'), findsNothing);
  });

  testWidgets('a long story opens the screen built for reading', (
    tester,
  ) async {
    var opened = 0;
    await showCard(
      tester,
      served: _card(body: _whole),
      onOpen: () => opened++,
    );

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    expect(
      opened,
      1,
      reason: 'more means read it, and reading happens on the story screen',
    );
    expect(
      find.byType(AppSheet),
      findsNothing,
      reason: 'a sheet cannot like, comment, share, or show a heading',
    );
    expect(
      find.text('less'),
      findsNothing,
      reason: 'it never grew inside the card, so there is nothing to collapse',
    );
  });

  testWidgets('a middling story still opens where it stands', (tester) async {
    var opened = 0;
    await showCard(
      tester,
      served: _card(body: _opening),
      onOpen: () => opened++,
    );

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    expect(opened, 0, reason: 'it fits, so it never leaves the feed');
    expect(find.byType(AppSheet), findsNothing);
    expect(find.text('less'), findsOneWidget);
    expect(richTextWith('vast empire'), findsOneWidget);
  });

  testWidgets('a story the card already holds needs no second trip', (
    tester,
  ) async {
    await showCard(tester, story: _card(body: _middling));

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    expect(richTextWith('borrowed desk'), findsOneWidget);
  });

  testWidgets('the header no longer guesses how long the read takes', (
    tester,
  ) async {
    await showCard(tester);

    expect(find.textContaining('min read'), findsNothing);
  });

  testWidgets('collapsing puts the excerpt back', (tester) async {
    await showCard(tester, served: _card(body: _opening));

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('less'));
    await tester.pump();

    expect(find.text('more'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
