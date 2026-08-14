import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/double_tap_like.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

Future<void> showPicture(
  WidgetTester tester, {
  required bool isLiked,
  VoidCallback? onLike,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: DoubleTapLike(
          isLiked: isLiked,
          onLike: onLike,
          child: const SizedBox(width: 300, height: 300),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder heart({required bool filled}) =>
    find.byIcon(filled ? Icons.favorite : Icons.favorite_border);

Future<void> doubleTap(WidgetTester tester) async {
  final spot = tester.getCenter(find.byType(DoubleTapLike));
  await tester.tapAt(spot, pointer: 1);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(spot, pointer: 2);
  await tester.pump();
}

void main() {
  testWidgets('two taps on a picture like it', (tester) async {
    var likes = 0;
    await showPicture(tester, isLiked: false, onLike: () => likes++);

    await doubleTap(tester);
    await tester.pumpAndSettle();

    expect(likes, 1);
  });

  testWidgets('two taps on one already liked take the like back', (
    tester,
  ) async {
    var taken = 0;
    await showPicture(tester, isLiked: true, onLike: () => taken++);

    await doubleTap(tester);
    await tester.pumpAndSettle();

    expect(taken, 1);
  });

  testWidgets('a heart comes and then goes', (tester) async {
    await showPicture(tester, isLiked: false, onLike: () {});

    expect(heart(filled: true), findsNothing, reason: 'nothing before the tap');

    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(heart(filled: true), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      heart(filled: true),
      findsNothing,
      reason: 'it leaves the picture as it found it',
    );
  });

  testWidgets('taking a like back draws the very same heart', (tester) async {
    await showPicture(tester, isLiked: true, onLike: () {});

    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 200));
    addTearDown(() => tester.pumpAndSettle());

    expect(heart(filled: true), findsOneWidget);
    expect(
      heart(filled: false),
      findsNothing,
      reason: 'giving and taking back look alike, as asked',
    );
  });

  testWidgets('the heart it draws belongs to the theme', (tester) async {
    await showPicture(tester, isLiked: false, onLike: () {});

    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 200));
    addTearDown(() => tester.pumpAndSettle());

    expect(
      tester.widget<Icon>(heart(filled: true)).color,
      AppColors.midnight.like,
    );
  });

  testWidgets('a picture nobody may like does not answer a double tap', (
    tester,
  ) async {
    await showPicture(tester, isLiked: false);

    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 200));
    addTearDown(() => tester.pumpAndSettle());

    expect(heart(filled: true), findsNothing);
  });

  testWidgets('the heart never swallows a tap meant for the picture', (
    tester,
  ) async {
    await showPicture(tester, isLiked: false, onLike: () {});

    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 200));
    addTearDown(() => tester.pumpAndSettle());

    final shield = find.descendant(
      of: find.byType(DoubleTapLike),
      matching: find.byType(IgnorePointer),
    );

    expect(tester.widget<IgnorePointer>(shield).ignoring, isTrue);
  });
}
