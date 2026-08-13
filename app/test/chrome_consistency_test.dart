import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_back_button.dart';
import 'package:story_app/components/skeleton.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

double luminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final first = luminance(a);
  final second = luminance(b);
  final light = first > second ? first : second;
  final dark = first > second ? second : first;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  final palettes = {
    'midnight': AppColors.midnight,
    'paper': AppColors.paper,
    'blush': AppColors.blush,
    'maroon': AppColors.maroon,
  };

  group('separators whisper instead of shouting', () {
    for (final entry in palettes.entries) {
      test('${entry.key} keeps its border quiet against the surface', () {
        final ratio = contrast(entry.value.border, entry.value.surface);
        expect(
          ratio,
          lessThan(1.9),
          reason: 'a border this strong reads as a drawn box, not a hairline',
        );
      });

      test('${entry.key} still shows the border at all', () {
        expect(
          contrast(entry.value.border, entry.value.surface),
          greaterThan(1.03),
          reason: 'an invisible border is no separator',
        );
      });
    }
  });

  test('the hairline is thinner than a whole pixel of a dense screen', () {
    expect(AppSizes.hairline, lessThan(1));
  });

  testWidgets('the loader takes its colour from the theme', (tester) async {
    for (final entry in {'blush': blushTheme, 'maroon': maroonTheme}.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final theme = Theme.of(
        tester.element(find.byType(CircularProgressIndicator)),
      );
      final expected = entry.key == 'blush'
          ? AppColors.blush.accent
          : AppColors.maroon.accent;
      expect(
        theme.progressIndicatorTheme.color,
        expected,
        reason: '${entry.key} should not borrow another theme accent',
      );
      expect(
        theme.progressIndicatorTheme.color,
        isNot(AppColors.midnight.accent),
      );
    }
  });

  testWidgets('the back arrow lines up with the content beside it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(),
            title: const Text('Settings'),
          ),
          body: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('Appearance'),
          ),
        ),
      ),
    );
    await tester.pump();

    final arrow = tester.getTopLeft(find.byIcon(Icons.arrow_back)).dx;
    final content = tester.getTopLeft(find.text('Appearance')).dx;

    expect(
      (arrow - content).abs(),
      lessThan(2),
      reason: 'the arrow sat 8dp left of everything else on the screen',
    );
  });

  testWidgets('the waiting rows stand where the real ones will', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: midnightTheme,
        home: const Scaffold(body: ConversationSkeleton()),
      ),
    );
    await tester.pump();

    final boxes = tester.widgetList<SkeletonBox>(find.byType(SkeletonBox));
    expect(boxes.length, 4, reason: 'avatar, name, handle, and the time');

    final avatar = boxes.first;
    expect(avatar.width, 52, reason: 'the real avatar is 52');
    expect(avatar.height, 52);
    expect(avatar.radius, AppRadius.pill, reason: 'and it is a circle');

    final avatarLeft = tester.getTopLeft(find.byType(SkeletonBox).first).dx;
    final timeRight = tester.getTopRight(find.byType(SkeletonBox).last).dx;
    final width = tester.getSize(find.byType(ConversationSkeleton)).width;
    expect(avatarLeft, lessThan(4), reason: 'the avatar hugs the left');
    expect(
      timeRight,
      greaterThan(width - 4),
      reason: 'the timestamp hugs the right, as it does on a real row',
    );
  });
}
