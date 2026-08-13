import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';

Story storyPosted({required String visibility, String? publishedAt}) => Story(
  storyId: 'st_1',
  slug: 'a-slug',
  title: 'A title',
  excerpt: 'An excerpt',
  body: 'A body',
  images: const [],
  imageRatio: null,
  visibility: visibility,
  publishedAt: publishedAt,
  createdAt: DateTime.now().toUtc().toIso8601String(),
  updatedAt: DateTime.now().toUtc().toIso8601String(),
  readingMinutes: 1,
  likes: 0,
  comments: 0,
  isLiked: false,
  author: const StoryAuthor(
    userId: 'us_1',
    username: 'quiet_fox',
    displayName: 'quiet fox',
    avatarSeed: 'seed',
  ),
);

String hoursAgo(int hours) => DateTime.now()
    .toUtc()
    .subtract(Duration(hours: hours))
    .toIso8601String();

void main() {
  test('a draft is always editable', () {
    expect(storyPosted(visibility: 'draft').isEditable, isTrue);
  });

  test('a story published minutes ago can still be fixed', () {
    final story = storyPosted(visibility: 'public', publishedAt: hoursAgo(1));
    expect(story.isEditable, isTrue);
  });

  test('a story published yesterday is past its window', () {
    final story = storyPosted(visibility: 'public', publishedAt: hoursAgo(25));
    expect(
      story.isEditable,
      isFalse,
      reason: 'the server refuses this edit, so we must not offer it',
    );
  });

  test('the boundary belongs to the writer', () {
    expect(
      storyPosted(visibility: 'public', publishedAt: hoursAgo(23)).isEditable,
      isTrue,
    );
  });

  test('a private story that was never published stays editable', () {
    expect(storyPosted(visibility: 'private').isEditable, isTrue);
  });

  test('an unreadable stamp does not lock the writer out', () {
    final story = storyPosted(visibility: 'public', publishedAt: 'not a date');
    expect(story.isEditable, isTrue);
  });
}
