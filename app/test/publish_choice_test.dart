import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';

Map<String, dynamic> wire({
  String visibility = 'public',
  String? scheduledFor,
}) => {
  'story_id': 'st_1',
  'author': {
    'user_id': 'us_1',
    'display_name': 'deepak',
    'avatar_seed': 'seed',
    'username': 'deepak',
  },
  'title': 'A title',
  'excerpt': 'An excerpt',
  'body': 'A body',
  'visibility': visibility,
  'slug': 'a-slug',
  'counts': {'likes': 0, 'comments': 0},
  'reading_minutes': 2,
  'is_liked': false,
  'published_at': null,
  'scheduled_for': scheduledFor,
  'created_at': '2026-08-14T03:00:00Z',
  'updated_at': '2026-08-14T03:00:00Z',
};

void main() {
  test('draft is not a choice the publish endpoint accepts', () {
    expect(
      publishableVisibilities.contains('draft'),
      isFalse,
      reason: 'the server takes public, private or scheduled and nothing else',
    );
  });

  test('every other type is publishable', () {
    for (final visibility in ['public', 'private', 'scheduled']) {
      expect(publishableVisibilities.contains(visibility), isTrue);
    }
  });

  test('a story remembers what it already is', () {
    for (final visibility in ['draft', 'public', 'private', 'scheduled']) {
      expect(Story.fromJson(wire(visibility: visibility)).visibility, visibility);
    }
  });

  test('a scheduled story carries the time it was given', () {
    final story = Story.fromJson(
      wire(visibility: 'scheduled', scheduledFor: '2026-08-20T09:30:00Z'),
    );

    expect(story.scheduledFor, '2026-08-20T09:30:00Z');
    expect(
      DateTime.tryParse(story.scheduledFor!),
      isNotNull,
      reason: 'the composer reopens the picker with this',
    );
  });

  test('a story with no schedule says so', () {
    expect(Story.fromJson(wire()).scheduledFor, isNull);
  });
}
