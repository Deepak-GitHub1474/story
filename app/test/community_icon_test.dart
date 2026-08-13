import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/communities/widgets/community_icon.dart';

void main() {
  test('a room wears the icon of what it is about', () {
    expect(iconForCategory('grief'), isNot(iconForCategory('joy')));
    expect(iconForCategory('work'), isNot(iconForCategory('love')));
    expect(iconForCategory('money'), Icons.payments_outlined);
    expect(iconForCategory('heartbreak'), Icons.heart_broken_outlined);
  });

  test('every seeded category has its own glyph', () {
    const seeded = [
      'joy',
      'love',
      'friendship',
      'wins',
      'beginnings',
      'everyday',
      'wonder',
      'starting-over',
      'making',
      'work',
      'job-search',
      'money',
      'study',
      'family',
      'identity',
      'health',
      'mental-health',
      'caregiving',
      'loneliness',
      'heartbreak',
      'sacrifice',
      'grief',
    ];

    final chosen = {for (final id in seeded) id: iconForCategory(id)};
    expect(
      chosen.values.toSet().length,
      seeded.length,
      reason: 'two rooms sharing a glyph is what it looked like before',
    );
    expect(
      chosen.values,
      everyElement(isNot(Icons.forum_outlined)),
      reason: 'forum_outlined is the fallback, not an answer',
    );
  });

  test('an unknown room still gets something', () {
    expect(iconForCategory('not-a-category'), Icons.forum_outlined);
    expect(iconForCategory(null), Icons.forum_outlined);
    expect(iconForCategory(''), Icons.forum_outlined);
  });
}
