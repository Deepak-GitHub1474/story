import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/communities/models/community_models.dart';
import 'package:story_app/features/communities/providers/community_providers.dart';
import 'package:story_app/features/stories/screens/composer_screen.dart';
import 'package:story_app/theme/app_theme.dart';

Community aCommunity(String name) => Community(
  slug: name.toLowerCase().replaceAll(' ', '-'),
  name: name,
  description: '',
  categoryId: 'cat',
  members: 4,
  stories: 2,
  isMember: true,
);

Future<void> showComposer(
  WidgetTester tester, {
  List<Community> communities = const [],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myCommunitiesProvider.overrideWith((ref) async => communities),
      ],
      child: MaterialApp(
        theme: midnightTheme,
        home: const ComposerScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> pickCommunity(WidgetTester tester, String name) async {
  await tester.tap(find.text('No community'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

double pillEdge(WidgetTester tester) =>
    tester.getRect(find.byIcon(Icons.keyboard_arrow_down)).right;

void main() {
  testWidgets('the community picks the left edge, the type the right', (
    tester,
  ) async {
    await showComposer(tester, communities: [aCommunity('Night Owls')]);

    final where = tester.getRect(find.text('No community'));
    final type = tester.getRect(find.text('Draft'));

    expect(
      type.left,
      greaterThan(where.right),
      reason: 'the type selector belongs after the community, not beside it',
    );
    expect(
      type.right,
      greaterThan(300),
      reason: 'and it should sit against the right edge of the sheet',
    );
  });

  testWidgets('the community name is not cut short to make room', (
    tester,
  ) async {
    await showComposer(tester, communities: [aCommunity('Night Owls')]);

    final words = tester.renderObject<RenderParagraph>(
      find.text('No community'),
    );

    expect(
      words.size.width,
      greaterThanOrEqualTo(words.getMaxIntrinsicWidth(double.infinity)),
      reason: 'a Spacer used to eat half the row and clip this to "No co..."',
    );
  });

  testWidgets('a long community name still gives the type its place', (
    tester,
  ) async {
    await showComposer(
      tester,
      communities: [aCommunity('The Very Long Community Name Society')],
    );

    final type = tester.getRect(find.text('Draft'));

    expect(type.right, greaterThan(300));
    expect(
      type.left,
      greaterThan(tester.getRect(find.byType(TextField).first).left),
      reason: 'the chip is never pushed off the screen',
    );
  });

  testWidgets('a long name does not stretch the picker', (tester) async {
    await showComposer(
      tester,
      communities: [aCommunity('Astronomy And Night Sky Watchers')],
    );

    final empty = pillEdge(tester);
    await pickCommunity(tester, 'Astronomy And Night Sky Watchers');

    expect(
      pillEdge(tester),
      empty,
      reason: 'the picker is one width, whoever is picked',
    );
  });

  testWidgets('a short name does not shrink the picker either', (tester) async {
    await showComposer(tester, communities: [aCommunity('Owls')]);

    final empty = pillEdge(tester);
    await pickCommunity(tester, 'Owls');

    expect(pillEdge(tester), empty);
  });

  testWidgets('a name too long for the picker is cut, not wrapped', (
    tester,
  ) async {
    await showComposer(
      tester,
      communities: [aCommunity('Astronomy And Night Sky Watchers')],
    );
    await pickCommunity(tester, 'Astronomy And Night Sky Watchers');

    final words = tester.renderObject<RenderParagraph>(
      find.text('Astronomy And Night Sky Watchers'),
    );

    expect(
      words.size.width,
      lessThan(words.getMaxIntrinsicWidth(double.infinity)),
      reason: 'it should be ellipsised, which is what the fixed width buys',
    );
    expect(
      words.size.height,
      lessThan(30),
      reason: 'cut on one line, never spilling onto a second',
    );
  });

  testWidgets('the picker is wide enough for "No community" as it stands', (
    tester,
  ) async {
    await showComposer(tester, communities: [aCommunity('Owls')]);

    final words = tester.renderObject<RenderParagraph>(
      find.text('No community'),
    );

    expect(
      words.size.width,
      greaterThanOrEqualTo(words.getMaxIntrinsicWidth(double.infinity)),
      reason: 'the resting label is the one thing that must never be cut',
    );
  });

  testWidgets('with no community of your own the type still sits right', (
    tester,
  ) async {
    await showComposer(tester);

    expect(find.text('No community'), findsNothing);
    expect(tester.getRect(find.text('Draft')).right, greaterThan(300));
  });
}
