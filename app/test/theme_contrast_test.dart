import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/theme/tokens.dart';

double _channel(double value) =>
    value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) as double;

double luminance(Color colour) =>
    0.2126 * _channel(colour.r) +
    0.7152 * _channel(colour.g) +
    0.0722 * _channel(colour.b);

double contrast(Color a, Color b) {
  final one = luminance(a);
  final other = luminance(b);
  return (max(one, other) + 0.05) / (min(one, other) + 0.05);
}

const looks = {
  'midnight': AppColors.midnight,
  'paper': AppColors.paper,
  'blush': AppColors.blush,
  'maroon': AppColors.maroon,
};

void main() {
  test('a filled button is readable in every theme', () {
    for (final look in looks.entries) {
      expect(
        contrast(look.value.accentStrong, look.value.accentText),
        greaterThanOrEqualTo(4.5),
        reason: '${look.key} fails the readable-text floor',
      );
    }
  });

  test('every theme writes light on a deep fill, the way maroon does', () {
    for (final look in looks.entries) {
      expect(
        luminance(look.value.accentText),
        greaterThan(luminance(look.value.accentStrong)),
        reason: '${look.key} puts dark text on its button, which we moved away '
            'from so all four read alike',
      );
    }
  });

  test('the accent still shows up as ink on the page', () {
    for (final look in looks.entries) {
      expect(
        contrast(look.value.accent, look.value.bg),
        greaterThanOrEqualTo(3),
        reason: '${look.key} draws its active tab and rings in accent',
      );
    }
  });

  test('a filled button stands apart from the page behind it', () {
    for (final look in looks.entries) {
      expect(
        contrast(look.value.accentStrong, look.value.bg),
        greaterThanOrEqualTo(2),
        reason: '${look.key} would sink its button into the background',
      );
    }
  });
}
