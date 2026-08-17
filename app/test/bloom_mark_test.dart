import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/bloom_mark.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

Future<void> showBloom(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: BloomMark(width: 176, height: 236)),
    ),
  );
  await tester.pumpAndSettle();
}

Image bloomWidget(WidgetTester tester) => tester.widget<Image>(
  find.descendant(of: find.byType(BloomMark), matching: find.byType(Image)),
);

String bloomShown(WidgetTester tester) {
  final source = bloomWidget(tester).image;
  final art = source is ResizeImage ? source.imageProvider : source;
  return (art as AssetImage).assetName;
}

void main() {
  testWidgets('the dark theme wears the indigo bloom', (tester) async {
    await showBloom(tester, midnightTheme);

    expect(bloomShown(tester), AppArt.bloomIndigo);
  });

  testWidgets('the light theme wears the indigo bloom too', (tester) async {
    await showBloom(tester, paperTheme);

    expect(
      bloomShown(tester),
      AppArt.bloomIndigo,
      reason: 'system follows one of these two, so both must agree',
    );
  });

  testWidgets('the pink theme wears the pink bloom', (tester) async {
    await showBloom(tester, blushTheme);

    expect(bloomShown(tester), AppArt.bloomPink);
  });

  testWidgets('the maroon theme keeps the maroon bloom', (tester) async {
    await showBloom(tester, maroonTheme);

    expect(bloomShown(tester), AppArt.bloomMaroon);
  });

  testWidgets('no two looks share a bloom that clashes with them', (
    tester,
  ) async {
    final worn = <String>{};

    for (final theme in [midnightTheme, paperTheme, blushTheme, maroonTheme]) {
      await showBloom(tester, theme);
      worn.add(bloomShown(tester));
    }

    expect(
      worn,
      {AppArt.bloomIndigo, AppArt.bloomPink, AppArt.bloomMaroon},
      reason: 'three drawings cover four looks, and no look borrows a clash',
    );
  });

  testWidgets('the bloom is unpacked at the size it is drawn, not its own', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await showBloom(tester, midnightTheme);

    final sized = bloomWidget(tester).image as ResizeImage;

    expect(sized.width, (176 * 3).round());
    expect(sized.height, (236 * 3).round());
    expect(
      sized.width! * sized.height!,
      lessThan(1024 * 1536),
      reason: 'a 1024x1536 drawing has no business filling memory at 176pt',
    );
  });

  testWidgets('changing look never leaves a hole where the bloom was', (
    tester,
  ) async {
    await showBloom(tester, midnightTheme);
    expect(bloomWidget(tester).gaplessPlayback, isTrue);

    await showBloom(tester, blushTheme);

    expect(
      bloomShown(tester),
      AppArt.bloomPink,
      reason: 'the new one arrives without the old one blinking out first',
    );
  });

  testWidgets('the bloom never takes a tap meant for the form', (tester) async {
    await showBloom(tester, midnightTheme);

    final shield = find.descendant(
      of: find.byType(BloomMark),
      matching: find.byType(IgnorePointer),
    );

    expect(tester.widget<IgnorePointer>(shield).ignoring, isTrue);
  });

  test('every bloom is on disk and named in the build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final art in [
      AppArt.bloomIndigo,
      AppArt.bloomPink,
      AppArt.bloomMaroon,
    ]) {
      expect(File(art).existsSync(), isTrue, reason: '$art is missing');
      expect(
        pubspec.contains(art),
        isTrue,
        reason: '$art would be left out of the app',
      );
    }
  });
}
