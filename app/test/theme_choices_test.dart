import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/theme/app_theme.dart';
import 'package:story_app/theme/tokens.dart';

double _contrast(Color a, Color b) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final first = luminance(a);
  final second = luminance(b);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('the two extra themes never follow the system', () {
    test('blush and maroon each resolve to one fixed look', () {
      expect(fixedThemeFor('blush'), isNotNull);
      expect(fixedThemeFor('maroon'), isNotNull);
    });

    test('the neutral choices leave light and dark to the system', () {
      expect(fixedThemeFor('system'), isNull);
      expect(fixedThemeFor('paper'), isNull);
      expect(fixedThemeFor('midnight'), isNull);
    });

    test('an unknown name falls back to the neutral pair', () {
      expect(fixedThemeFor('whatever'), isNull);
    });
  });

  group('every theme carries its own colours', () {
    test('blush is the palette that was asked for', () {
      expect(AppColors.blush.accentStrong, const Color(0xFFFF6FA3));
      expect(AppColors.blush.bg, const Color(0xFFFFF5F7));
      expect(AppColors.blush.textPrimary, const Color(0xFF1A1A1A));
      expect(AppColors.blush.textMuted, const Color(0xFF8C8C8C));
    });

    test('maroon is the palette that was asked for', () {
      expect(AppColors.maroon.bg, const Color(0xFF1A1114));
      expect(AppColors.maroon.textPrimary, const Color(0xFFF3F0EF));
      expect(AppColors.maroon.textMuted, const Color(0xFFA3B0A4));
      expect(AppColors.maroon.accentStrong, const Color(0xFF85223E));
      expect(AppColors.maroon.accent, const Color(0xFFD06A87));
    });

    test('blush is built light and maroon dark', () {
      expect(blushTheme.brightness, Brightness.light);
      expect(maroonTheme.brightness, Brightness.dark);
    });
  });

  group('text stays readable on every theme', () {
    for (final entry in {
      'paper': AppColors.paper,
      'midnight': AppColors.midnight,
      'blush': AppColors.blush,
      'maroon': AppColors.maroon,
    }.entries) {
      test('${entry.key} keeps body text clear of its background', () {
        expect(
          _contrast(entry.value.textPrimary, entry.value.bg),
          greaterThan(4.5),
        );
      });

      test('${entry.key} keeps button text clear of its fill', () {
        expect(
          _contrast(entry.value.accentText, entry.value.accentStrong),
          greaterThan(4.5),
        );
      });

      test('${entry.key} keeps an accent mark visible on its background', () {
        expect(_contrast(entry.value.accent, entry.value.bg), greaterThan(3));
      });
    }
  });
}
