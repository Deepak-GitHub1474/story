import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    MaterialApp(
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

  testWidgets('share is a paper plane, not a box with an arrow', (
    tester,
  ) async {
    await showPost(tester, onShare: () {});

    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsNothing);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
  });

  testWidgets('the action icons are big enough to aim at', (tester) async {
    await showPost(tester, onLike: () {}, onShare: () {});

    for (final glyph in [
      Icons.favorite_border,
      Icons.chat_bubble_outline,
      Icons.near_me_outlined,
    ]) {
      final icon = tester.widget<Icon>(find.byIcon(glyph));
      expect(icon.size, AppSizes.iconAction, reason: '$glyph');
      expect(icon.size, greaterThan(AppSizes.iconMd));
    }
  });
}
