import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_text_field.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/communities/providers/community_providers.dart';
import 'package:story_app/features/stories/data/story_repository.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/screens/composer_screen.dart';
import 'package:story_app/theme/app_theme.dart';

class DraftingRepository implements StoryRepository {
  final briefs = <String>[];
  final polishes = <String>[];

  @override
  Future<Result<({String title, String body})>> draft({
    required String subject,
    required String brief,
  }) async {
    briefs.add(brief);
    return Success((
      title: 'Draft ${briefs.length}',
      body: 'Story ${briefs.length}',
    ));
  }

  @override
  Future<Result<String>> polish({
    required String text,
    required String instruction,
  }) async {
    polishes.add(instruction);
    return Success(text);
  }

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

Finder sheetField(int index) => find.descendant(
  of: find.byType(AppTextField).at(index),
  matching: find.byType(TextField),
);

Future<DraftingRepository> writeAStory(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = DraftingRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyRepositoryProvider.overrideWithValue(repository),
        myCommunitiesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: midnightTheme,
        home: const ComposerScreen(),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.byIcon(Icons.auto_fix_high_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(sheetField(0), 'a coffee at midday');
  await tester.enterText(sheetField(1), 'nothing much happened');
  await tester.pump();
  await tester.tap(find.text('Write it'));
  await tester.pumpAndSettle();

  return repository;
}

Future<void> askForChange(WidgetTester tester, String change) async {
  await tester.tap(find.text('Ask for changes'));
  await tester.pumpAndSettle();
  await tester.enterText(sheetField(0), change);
  await tester.pump();
  await tester.tap(find.text('Rewrite it'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the write sheet keeps its button above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storyRepositoryProvider.overrideWithValue(DraftingRepository()),
          myCommunitiesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: midnightTheme,
          home: const ComposerScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.auto_fix_high_outlined));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('Write it')).bottom,
      lessThanOrEqualTo(852 - 336),
      reason: 'this sheet works because it stays short, so keep it short',
    );
  });

  testWidgets('asking for a change writes the story again, not tidies it', (
    tester,
  ) async {
    final repository = await writeAStory(tester);

    await askForChange(tester, 'make it a developer debugging');

    expect(
      repository.briefs.length,
      2,
      reason: 'a change of subject needs a new draft, not a polish',
    );
    expect(
      repository.polishes,
      isEmpty,
      reason: 'polish is forbidden from inventing, so it can never do this',
    );
  });

  testWidgets('the new instruction is carried on top of the first brief', (
    tester,
  ) async {
    final repository = await writeAStory(tester);

    await askForChange(tester, 'make it a developer debugging');

    expect(repository.briefs[1], contains('nothing much happened'));
    expect(repository.briefs[1], contains('make it a developer debugging'));
  });

  testWidgets('a second change stacks on the first, it does not replace it', (
    tester,
  ) async {
    final repository = await writeAStory(tester);

    await askForChange(tester, 'make it a developer debugging');
    await askForChange(tester, 'end it at dawn');

    expect(repository.briefs[2], contains('nothing much happened'));
    expect(repository.briefs[2], contains('make it a developer debugging'));
    expect(repository.briefs[2], contains('end it at dawn'));
  });

  testWidgets('the whole story on screen changes, title and all', (
    tester,
  ) async {
    await writeAStory(tester);

    expect(find.text('Draft 1'), findsOneWidget);
    expect(find.text('Story 1'), findsOneWidget);

    await askForChange(tester, 'make it a developer debugging');

    expect(find.text('Story 2'), findsOneWidget);
    expect(find.text('Story 1'), findsNothing);
    expect(
      find.text('Draft 2'),
      findsOneWidget,
      reason: 'the title belongs to the new story, not the old one',
    );
  });

  testWidgets('a change that made it worse can be stepped back', (
    tester,
  ) async {
    await writeAStory(tester);
    expect(
      find.text('Back to the one before'),
      findsNothing,
      reason: 'nothing to step back to yet',
    );

    await askForChange(tester, 'make it a developer debugging');
    expect(find.text('Story 2'), findsOneWidget);

    await tester.tap(find.text('Back to the one before'));
    await tester.pumpAndSettle();

    expect(find.text('Story 1'), findsOneWidget);
    expect(find.text('Draft 1'), findsOneWidget);
    expect(find.text('Story 2'), findsNothing);
  });

  testWidgets('stepping back also winds the brief back', (tester) async {
    final repository = await writeAStory(tester);

    await askForChange(tester, 'make it a developer debugging');
    await tester.tap(find.text('Back to the one before'));
    await tester.pumpAndSettle();

    await askForChange(tester, 'end it at dawn');

    expect(
      repository.briefs.last,
      isNot(contains('developer debugging')),
      reason: 'the undone change must not haunt the next one',
    );
    expect(repository.briefs.last, contains('end it at dawn'));
  });

  testWidgets('a redrawn story survives the sheet closing by mistake', (
    tester,
  ) async {
    await writeAStory(tester);
    await askForChange(tester, 'make it a developer debugging');

    await tester.tapAt(const Offset(200, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Story 2'),
      findsOneWidget,
      reason: 'reopening must bring back the redrawn one, not the first',
    );
  });
}
