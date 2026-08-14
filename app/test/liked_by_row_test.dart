import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_avatar.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/widgets/liked_by_row.dart';
import 'package:story_app/theme/app_theme.dart';

List<StoryAuthor> people(int count) => [
  for (var index = 0; index < count; index++)
    StoryAuthor(
      userId: 'us_$index',
      username: 'reader_$index',
      displayName: 'Reader $index',
      avatarSeed: 'seed_$index',
    ),
];

Future<void> showRow(
  WidgetTester tester, {
  required int shown,
  required int likes,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: LikedByRow(people: people(shown), likes: likes, onTap: onTap),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('nobody liked it, so the row is not there', (tester) async {
    await showRow(tester, shown: 0, likes: 0);

    expect(find.byType(AppAvatar), findsNothing);
    expect(find.textContaining('Liked by'), findsNothing);
  });

  testWidgets('one like shows one face and that name', (tester) async {
    await showRow(tester, shown: 1, likes: 1);

    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.textContaining('reader_0'), findsOneWidget);
    expect(find.textContaining('and others'), findsNothing);
  });

  testWidgets('two likes show two faces', (tester) async {
    await showRow(tester, shown: 2, likes: 2);

    expect(find.byType(AppAvatar), findsNWidgets(2));
    expect(find.textContaining('and 1 other'), findsOneWidget);
  });

  testWidgets('three likes show three faces', (tester) async {
    await showRow(tester, shown: 3, likes: 3);

    expect(find.byType(AppAvatar), findsNWidgets(3));
    expect(find.textContaining('and others'), findsOneWidget);
  });

  testWidgets('a crowd still shows three faces and one name', (tester) async {
    await showRow(tester, shown: 3, likes: 4210);

    expect(
      find.byType(AppAvatar),
      findsNWidgets(likedByPreview),
      reason: 'the row never grows with the crowd',
    );
    expect(find.textContaining('reader_0'), findsOneWidget);
    expect(find.textContaining('and others'), findsOneWidget);
  });

  testWidgets('the row opens the list of everyone who liked it', (
    tester,
  ) async {
    var opened = 0;
    await showRow(tester, shown: 3, likes: 12, onTap: () => opened++);

    await tester.tap(find.textContaining('Liked by'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('the empty space beside the names is not a button', (
    tester,
  ) async {
    var opened = 0;
    await showRow(tester, shown: 1, likes: 1, onTap: () => opened++);

    final row = tester.getRect(find.byType(LikedByRow));
    final words = tester.getRect(find.byType(Text).first);

    expect(
      words.right,
      lessThan(row.right - 40),
      reason: 'the test needs blank space to the right to be worth anything',
    );

    await tester.tapAt(Offset(row.right - 12, words.center.dy));
    await tester.pump();

    expect(opened, 0, reason: 'that is empty card, not the liked-by line');
  });

  testWidgets('the names themselves still open the drawer', (tester) async {
    var opened = 0;
    await showRow(tester, shown: 1, likes: 1, onTap: () => opened++);

    await tester.tap(find.textContaining('Liked by'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a face opens the drawer too', (tester) async {
    var opened = 0;
    await showRow(tester, shown: 2, likes: 2, onTap: () => opened++);

    await tester.tap(find.byType(AppAvatar).first);
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('the faces overlap instead of running off the card', (
    tester,
  ) async {
    await showRow(tester, shown: 3, likes: 3);

    final faces = tester
        .widgetList<AppAvatar>(find.byType(AppAvatar))
        .toList();
    expect(faces.every((face) => face.size == 18), isTrue);

    final boxes = tester
        .widgetList(find.byType(AppAvatar))
        .mapIndexed((index, _) => tester.getTopLeft(find.byType(AppAvatar).at(index)).dx)
        .toList();
    expect(boxes[1] - boxes[0], lessThan(18), reason: 'they must overlap');
  });
}

extension<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E element) convert) sync* {
    var index = 0;
    for (final element in this) {
      yield convert(index++, element);
    }
  }
}
