import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_button.dart';
import 'package:story_app/components/app_sheet.dart';
import 'package:story_app/components/app_text_field.dart';
import 'package:story_app/components/story_text.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/communities/providers/community_providers.dart';
import 'package:story_app/features/stories/data/story_repository.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/screens/composer_screen.dart';
import 'package:story_app/theme/app_theme.dart';

class WritingRepository implements StoryRepository {
  WritingRepository({this.story = 'A whole story.'});

  final String story;

  @override
  Future<Result<({String title, String body})>> draft({
    required String subject,
    required String brief,
  }) async => Success((title: 'The Long Way Back', body: story));

  @override
  Future<Result<String>> polish({
    required String text,
    required String instruction,
  }) async => Success('$text, tidied');

  @override
  Future<Result<Story>> create({
    String? title,
    required String body,
    String? sharedStoryId,
    List<String> images = const [],
    double? imageRatio,
    String imageFit = 'cover',
  }) async => const Failure(code: 'OFFLINE', message: 'Not now.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showComposer(WidgetTester tester, {String? story}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyRepositoryProvider.overrideWithValue(
          WritingRepository(story: story ?? 'A whole story.'),
        ),
        myCommunitiesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: midnightTheme,
        home: const ComposerScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> dismissTheSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 8));
  await tester.pumpAndSettle();
}

Finder sheetField(int index) => find.descendant(
  of: find.byType(AppTextField).at(index),
  matching: find.byType(TextField),
);

Future<void> writeOne(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.auto_fix_high_outlined));
  await tester.pumpAndSettle();

  await tester.enterText(sheetField(0), 'leaving home');
  await tester.enterText(sheetField(1), 'it was raining');
  await tester.pump();
  await tester.tap(find.text('Write it'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a written story survives the sheet being closed by mistake', (
    tester,
  ) async {
    await showComposer(tester);
    await writeOne(tester);

    expect(find.text('The Long Way Back'), findsWidgets, reason: 'preview open');

    await dismissTheSheet(tester);

    expect(
      find.text('A written story is waiting'),
      findsOneWidget,
      reason: 'a whole generation must not vanish on a stray tap',
    );
  });

  testWidgets('the bar opens the written story again', (tester) async {
    await showComposer(tester);
    await writeOne(tester);
    await dismissTheSheet(tester);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('The Long Way Back'), findsWidgets);
  });

  testWidgets('throwing it away takes the bar with it', (tester) async {
    await showComposer(tester);
    await writeOne(tester);
    await dismissTheSheet(tester);

    await tester.tap(find.byTooltip('Throw it away'));
    await tester.pumpAndSettle();

    expect(find.text('A written story is waiting'), findsNothing);
  });

  testWidgets('taking the written story clears the bar', (tester) async {
    await showComposer(tester);
    await writeOne(tester);

    await tester.tap(find.text('Use this'));
    await tester.pumpAndSettle();

    expect(find.text('A written story is waiting'), findsNothing);
  });

  testWidgets('a rewrite survives the sheet being closed by mistake', (
    tester,
  ) async {
    await showComposer(tester);

    await tester.enterText(find.byType(TextField).last, 'What I wrote myself');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'tidy it');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await dismissTheSheet(tester);

    expect(find.text('A rewrite is waiting'), findsOneWidget);
  });

  testWidgets('the preview keeps both buttons in view under a long story', (
    tester,
  ) async {
    await showComposer(
      tester,
      story: List.filled(120, 'A paragraph of the written story.').join('\n\n'),
    );
    await writeOne(tester);

    expect(
      find.ancestor(
        of: find.text('Use this'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
      reason: 'they used to sit at the end of 800 words of scrolling',
    );

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (final label in ['Use this', 'Ask for changes']) {
      expect(
        tester.getRect(find.text(label)).bottom,
        lessThanOrEqualTo(screen),
        reason: '$label must be on the screen without scrolling to it',
      );
    }
  });

  testWidgets('the long story itself still scrolls inside the preview', (
    tester,
  ) async {
    await showComposer(
      tester,
      story: List.filled(120, 'A paragraph of the written story.').join('\n\n'),
    );
    await writeOne(tester);

    expect(
      find.ancestor(
        of: find.text('Read it first'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
      reason: 'the title stays pinned at the top while the story moves',
    );
  });

  testWidgets('the preview is inset like every other sheet', (tester) async {
    await showComposer(tester);
    await writeOne(tester);

    final scroll = tester.widget<SingleChildScrollView>(
      find
          .descendant(
            of: find.byType(AppSheet),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    final padding = scroll.padding as EdgeInsets;

    expect(padding.left, AppSheet.insets.left);
    expect(padding.right, AppSheet.insets.right);
    expect(
      padding.top,
      AppSheet.insets.top,
      reason: 'the gap under the title bar is part of the shared look',
    );
  });

  testWidgets('the pinned buttons line up with the story above them', (
    tester,
  ) async {
    await showComposer(tester);
    await writeOne(tester);

    expect(
      tester.getTopLeft(find.byType(AppButton).first).dx,
      tester.getTopLeft(find.byType(StoryText)).dx,
      reason: 'the footer is fixed at AppSpacing.lg, so the body must match',
    );
  });

  testWidgets('nothing waiting means no bar in the way', (tester) async {
    await showComposer(tester);

    expect(find.text('Open'), findsNothing);
    expect(find.textContaining('is waiting'), findsNothing);
  });
}
