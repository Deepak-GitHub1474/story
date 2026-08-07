import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';

void main() {
  Map<String, dynamic> base() => {
    'story_id': 'sto_1',
    'author': {'user_id': 'usr_1', 'display_name': 'A', 'username': 'a'},
    'excerpt': 'mine',
    'visibility': 'public',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };

  test('story without a quote has no shared source', () {
    expect(Story.fromJson(base()).shared, isNull);
  });

  test('story parses the quoted source it was reshared from', () {
    final story = Story.fromJson({
      ...base(),
      'shared': {
        'story_id': 'sto_0',
        'title': 'Origin',
        'excerpt': 'theirs',
        'slug': 'origin',
        'author': {'user_id': 'usr_0', 'display_name': 'B', 'username': 'b'},
      },
    });

    expect(story.shared!.storyId, 'sto_0');
    expect(story.shared!.title, 'Origin');
    expect(story.shared!.excerpt, 'theirs');
    expect(story.shared!.author.username, 'b');
  });

  test('the quote survives a cache round trip', () {
    final story = Story.fromJson({
      ...base(),
      'shared': {
        'story_id': 'sto_0',
        'excerpt': 'theirs',
        'author': {'user_id': 'usr_0', 'display_name': 'B', 'username': 'b'},
      },
    });

    expect(Story.fromJson(story.toJson()).shared!.storyId, 'sto_0');
  });

  test('the quote survives an optimistic like', () {
    final story = Story.fromJson({
      ...base(),
      'shared': {
        'story_id': 'sto_0',
        'excerpt': 'theirs',
        'author': {'user_id': 'usr_0', 'display_name': 'B', 'username': 'b'},
      },
    });

    expect(story.copyWith(isLiked: true).shared!.storyId, 'sto_0');
  });
}
