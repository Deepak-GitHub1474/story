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

  testWidgets('a liked heart wears the colour of its theme', (tester) async {
    final looks = {
      midnightTheme: AppColors.midnight,
      paperTheme: AppColors.paper,
      blushTheme: AppColors.blush,
      maroonTheme: AppColors.maroon,
    };
    final worn = <Color?>[];

    for (final look in looks.entries) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: look.key,
            home: Scaffold(
              body: LikeIcon(isLiked: true, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heart = tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(heart.color, look.value.like, reason: '${look.value.like}');
      worn.add(heart.color);
    }

    expect(
      worn.toSet(),
      hasLength(looks.length),
      reason: 'every theme brings its own heart, none of them borrowed',
    );
  });
}
