import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';

StoryAuthor author({String? username}) => StoryAuthor.fromJson({
  'user_id': 'usr_1',
  'display_name': 'Deepak ✨',
  'avatar_seed': 'abc',
  if (username != null) 'username': username,
});

void main() {
  test('a person is shown by the name they chose to be known by', () {
    expect(author(username: 'dev_deepak').handle, 'dev_deepak');
  });

  test('a deleted account still reads as something', () {
    expect(author().handle, 'Deepak ✨');
  });
}
