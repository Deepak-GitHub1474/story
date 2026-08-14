import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/story_glyphs.dart';
import 'package:story_app/features/stories/widgets/story_post.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

import 'story_editable_test.dart' show storyPosted;

Future<void> showPost(
  WidgetTester tester, {
  VoidCallback? onLike,
  VoidCallback? onShare,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryPost(
              story: storyPosted(visibility: 'public'),
              onLike: onLike,
              onShare: onShare,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the heart answers wherever the post is shown', (tester) async {
    var likes = 0;
    await showPost(tester, onLike: () => likes++);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(likes, 1, reason: 'the profile passed no onLike, so this was dead');
  });

  testWidgets('share is a paper plane, drawn not borrowed', (tester) async {
    await showPost(tester, onShare: () {});

    expect(find.byType(ShareGlyph), findsOneWidget);
    expect(find.byIcon(Icons.near_me_outlined), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsNothing);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
  });

  testWidgets('comments are a rounded bubble, not the messages icon', (
    tester,
  ) async {
    await showPost(tester);

    expect(find.byType(CommentGlyph), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });

  testWidgets('the action icons are big enough to aim at', (tester) async {
    await showPost(tester, onLike: () {}, onShare: () {});

    final heart = tester.widget<Icon>(find.byIcon(Icons.favorite_border));
    expect(heart.size, AppSizes.iconAction);
    expect(heart.size, greaterThan(AppSizes.iconMd));

    expect(
      tester.widget<CommentGlyph>(find.byType(CommentGlyph)).size,
      AppSizes.iconAction,
    );
    expect(
      tester.widget<ShareGlyph>(find.byType(ShareGlyph)).size,
      AppSizes.iconAction,
    );
  });

  testWidgets('a liked heart is red in every theme', (tester) async {
    for (final theme in [midnightTheme, paperTheme, blushTheme, maroonTheme]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: LikeIcon(isLiked: true, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      final heart = tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(heart.color, AppInk.like, reason: 'the heart is red, always');
    }
  });
}
