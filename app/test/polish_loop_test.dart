import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/stories/data/story_repository.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/widgets/polish_sheet.dart';
import 'package:story_app/theme/app_theme.dart';

class AskedFor {
  const AskedFor(this.text, this.instruction);

  final String text;
  final String instruction;
}

class RecordingRepository implements StoryRepository {
  RecordingRepository(this.reply);

  final Result<String> Function(AskedFor asked) reply;
  final asks = <AskedFor>[];

  @override
  Future<Result<String>> polish({
    required String text,
    required String instruction,
  }) async {
    final asked = AskedFor(text, instruction);
    asks.add(asked);
    return reply(asked);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final handedOut = <String>[];

Future<RecordingRepository> showPolish(
  WidgetTester tester, {
  String text = 'The first thing I wrote.',
  Result<String> Function(AskedFor asked)? reply,
  String? startFrom,
  int startRounds = 0,
}) async {
  handedOut.clear();
  final repository = RecordingRepository(
    reply ?? (asked) => Success('version ${asked.instruction}'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [storyRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: PolishSheet(
            text: text,
            startFrom: startFrom,
            startRounds: startRounds,
            onDraft: (draft, _) => handedOut.add(draft),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return repository;
}

Future<void> askFor(WidgetTester tester, String instruction) async {
  await tester.enterText(find.byType(TextField).last, instruction);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pumpAndSettle();
}

IconButton runButton(WidgetTester tester) => tester.widget<IconButton>(
  find.ancestor(
    of: find.byIcon(Icons.arrow_upward_rounded),
    matching: find.byType(IconButton),
  ),
);

Future<RecordingRepository> openTheSheet(
  WidgetTester tester, {
  required String reply,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = RecordingRepository((asked) => Success(reply));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [storyRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPolishSheet(
                context: context,
                text: 'mine',
                onDraft: (draft, _) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('the first ask works on what the writer wrote', (tester) async {
    final repository = await showPolish(tester, text: 'Mine, as it stands.');

    await askFor(tester, 'shorter');

    expect(repository.asks.single.text, 'Mine, as it stands.');
    expect(repository.asks.single.instruction, 'shorter');
  });

  testWidgets('the second ask builds on the first answer, not the original', (
    tester,
  ) async {
    final repository = await showPolish(tester, text: 'Mine, as it stands.');

    await askFor(tester, 'shorter');
    await askFor(tester, 'warmer');

    expect(repository.asks.length, 2);
    expect(
      repository.asks[1].text,
      'version shorter',
      reason: 'asking again used to throw the first change away',
    );
    expect(repository.asks[1].instruction, 'warmer');
  });

  testWidgets('a third ask keeps stacking', (tester) async {
    final repository = await showPolish(tester);

    await askFor(tester, 'one');
    await askFor(tester, 'two');
    await askFor(tester, 'three');

    expect(repository.asks[2].text, 'version two');
  });

  testWidgets('what comes back is the latest version, not the first', (
    tester,
  ) async {
    await showPolish(tester);

    await askFor(tester, 'one');
    await askFor(tester, 'two');

    expect(find.text('version two'), findsOneWidget);
    expect(find.text('version one'), findsNothing);
  });

  testWidgets('the same change cannot be applied twice by accident', (
    tester,
  ) async {
    await showPolish(tester);

    await askFor(tester, 'shorter');

    expect(
      runButton(tester).onPressed,
      isNull,
      reason: 'the box is cleared, so there is nothing to repeat',
    );
  });

  testWidgets('taking the result hands back the version on screen', (
    tester,
  ) async {
    await showPolish(tester);
    await askFor(tester, 'one');

    expect(find.text('Use this version'), findsOneWidget);
    expect(find.text('Keep mine'), findsOneWidget);
  });

  testWidgets('the buttons are pinned, not buried under the preview', (
    tester,
  ) async {
    await showPolish(tester);
    await askFor(tester, 'one');

    expect(
      find.ancestor(
        of: find.text('Use this version'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
      reason: 'a button that scrolls out of sight is a button nobody finds',
    );
  });

  testWidgets('every version is handed out the moment it arrives', (
    tester,
  ) async {
    await showPolish(tester);

    await askFor(tester, 'one');
    await askFor(tester, 'two');

    expect(
      handedOut,
      ['version one', 'version two'],
      reason: 'the composer holds these, so a stray swipe cannot lose them',
    );
  });

  testWidgets('reopening carries on from where it was left', (tester) async {
    final repository = await showPolish(
      tester,
      text: 'the original',
      startFrom: 'what we had already',
      startRounds: 2,
    );

    expect(find.text('what we had already'), findsOneWidget);
    expect(find.text('2 changes in, each one on top of the last.'), findsOne);

    await askFor(tester, 'three');

    expect(
      repository.asks.single.text,
      'what we had already',
      reason: 'it must not fall back to the original after reopening',
    );
  });

  testWidgets('the buttons stay on screen behind a long piece and a keyboard', (
    tester,
  ) async {
    await openTheSheet(
      tester,
      reply: List.filled(60, 'A long line of the rewritten story.').join('\n'),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pump();

    await askFor(tester, 'tidy it');

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final button = tester.getRect(find.text('Use this version'));

    expect(
      button.bottom,
      lessThanOrEqualTo(screen - 336),
      reason: 'the footer used to sit under the keyboard, so nobody found it',
    );
  });

  testWidgets('a change that made it worse can be undone', (tester) async {
    await showPolish(tester, text: 'mine');

    await askFor(tester, 'one');
    expect(find.text('Undo that one'), findsNothing, reason: 'only one version');

    await askFor(tester, 'two');
    expect(find.text('version two'), findsOneWidget);

    await tester.tap(find.text('Undo that one'));
    await tester.pumpAndSettle();

    expect(find.text('version one'), findsOneWidget);
    expect(find.text('version two'), findsNothing);
    expect(
      handedOut.last,
      'version one',
      reason: 'the composer must be told, or it keeps the undone one',
    );
  });

  testWidgets('asking again after an undo builds on the one kept', (
    tester,
  ) async {
    final repository = await showPolish(tester, text: 'mine');

    await askFor(tester, 'one');
    await askFor(tester, 'two');
    await tester.tap(find.text('Undo that one'));
    await tester.pumpAndSettle();
    await askFor(tester, 'three');

    expect(repository.asks.last.text, 'version one');
  });

  testWidgets('an ask that fails keeps the version already earned', (
    tester,
  ) async {
    await showPolish(
      tester,
      reply: (asked) => asked.instruction == 'two'
          ? const Failure(code: 'AI_UNAVAILABLE', message: 'Not right now.')
          : Success('version ${asked.instruction}'),
    );

    await askFor(tester, 'one');
    await askFor(tester, 'two');

    expect(find.text('version one'), findsOneWidget, reason: 'not thrown away');
    expect(find.text('Not right now.'), findsOneWidget);
  });

  testWidgets('an ask that fails can be tried again as it stands', (
    tester,
  ) async {
    var refuse = true;
    final repository = await showPolish(
      tester,
      reply: (asked) => refuse
          ? const Failure(code: 'AI_UNAVAILABLE', message: 'Not right now.')
          : Success('made it'),
    );

    await askFor(tester, 'warmer');
    expect(
      runButton(tester).onPressed,
      isNotNull,
      reason: 'a refused change must not clear what they typed',
    );

    refuse = false;
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(repository.asks.length, 2);
    expect(repository.asks[1].instruction, 'warmer');
    expect(find.text('made it'), findsOneWidget);
  });
}
