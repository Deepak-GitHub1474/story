import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/communities/providers/community_providers.dart';
import 'package:story_app/features/stories/data/story_repository.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/screens/composer_screen.dart';
import 'package:story_app/theme/app_theme.dart';

class SavingRepository implements StoryRepository {
  final saved = <String>[];

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
  }) async {
    saved.add(body);
    return const Failure(code: 'OFFLINE', message: 'Not now.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a polished story is saved without touching the keyboard again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = SavingRepository();

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

    await tester.enterText(find.byType(TextField).last, 'What I wrote myself');
    await tester.pump();

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(
      repository.saved,
      ['What I wrote myself'],
      reason: 'typing starts a save, and it must be spent before we go on, or '
          'it fires later and passes this test for the wrong reason',
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'tidy it');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use this version'));
    await tester.pumpAndSettle();

    expect(
      find.text('What I wrote myself, tidied'),
      findsOneWidget,
      reason: 'the polished text lands in the composer',
    );

    repository.saved.clear();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(
      repository.saved,
      contains('What I wrote myself, tidied'),
      reason: 'setting controller.text fires no onChanged, so polishing used '
          'to leave the story clean and never autosave it',
    );
  });
}
