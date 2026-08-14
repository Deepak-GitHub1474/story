import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/widgets/likes_sheet.dart';

Map<String, dynamic> wire({
  required String username,
  String? displayName,
  bool isFollowing = false,
  bool followsMe = false,
  bool isMe = false,
}) => {
  'user_id': 'us_$username',
  'username': username,
  'display_name': displayName ?? username,
  'avatar_seed': 'seed',
  'is_following': isFollowing,
  'follows_me': followsMe,
  'is_me': isMe,
  'liked_at': '2026-08-14T04:00:00.000Z',
};

void main() {
  group('who gets which button', () {
    test('no button against yourself, however the server labelled it', () {
      final me = Liker.fromJson(wire(username: 'deepak', isMe: true));
      expect(actionFor(liker: me, isMe: true), LikerAction.none);
    });

    test('the app spots itself even when the flag has not shipped yet', () {
      final me = Liker.fromJson(wire(username: 'deepak'));

      expect(
        isSelf(liker: me, viewerId: 'us_deepak', viewerUsername: 'someone'),
        isTrue,
        reason: 'the id matches',
      );
      expect(
        isSelf(liker: me, viewerId: 'other', viewerUsername: 'deepak'),
        isTrue,
        reason: 'the handle matches, which is what saved this on the phone',
      );
      expect(
        isSelf(liker: me, viewerId: 'other', viewerUsername: 'someone'),
        isFalse,
      );
    });

    test('someone you follow gets Message, not Following', () {
      final friend = Liker.fromJson(
        wire(username: 'quiet_fox', isFollowing: true),
      );
      expect(actionFor(liker: friend, isMe: false), LikerAction.message);
    });

    test('a stranger gets Follow', () {
      final stranger = Liker.fromJson(wire(username: 'loud_bear'));
      expect(actionFor(liker: stranger, isMe: false), LikerAction.follow);
    });

    test('someone who follows you first gets Follow back', () {
      final admirer = Liker.fromJson(
        wire(username: 'loud_bear', followsMe: true),
      );
      expect(actionFor(liker: admirer, isMe: false), LikerAction.followBack);
    });

    test('following them back settles into Message', () {
      final mutual = Liker.fromJson(
        wire(username: 'loud_bear', followsMe: true, isFollowing: true),
      );
      expect(actionFor(liker: mutual, isMe: false), LikerAction.message);
    });

    test('an older payload leaves nobody waiting to be followed back', () {
      final page = LikersPage.fromJson({
        'items': [
          {
            'user_id': 'us_1',
            'username': 'quiet_fox',
            'display_name': 'Quiet Fox',
            'avatar_seed': 'seed',
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });

      expect(page.items.single.followsMe, isFalse);
    });
  });

  test('a liker knows whether you already follow them', () {
    final page = LikersPage.fromJson({
      'items': [
        wire(username: 'quiet_fox', isFollowing: true),
        wire(username: 'loud_bear'),
        wire(username: 'deepak', isMe: true),
      ],
      'next_cursor': null,
      'has_more': false,
    });

    expect(page.items.first.isFollowing, isTrue);
    expect(page.items[1].isFollowing, isFalse);
    expect(page.items[2].isMe, isTrue, reason: 'you cannot follow yourself');
  });

  test('an older payload without the flags still reads', () {
    final page = LikersPage.fromJson({
      'items': [
        {
          'user_id': 'us_1',
          'username': 'quiet_fox',
          'display_name': 'Quiet Fox',
          'avatar_seed': 'seed',
        },
      ],
      'next_cursor': null,
      'has_more': false,
    });

    expect(page.items.single.isFollowing, isFalse);
    expect(page.items.single.isMe, isFalse);
  });

  test('following someone flips only that row', () {
    final before = Liker.fromJson(wire(username: 'quiet_fox'));
    final after = before.copyWith(isFollowing: true);

    expect(after.isFollowing, isTrue);
    expect(after.person.username, 'quiet_fox');
    expect(before.isFollowing, isFalse, reason: 'the old row is untouched');
  });

  group('the search finds people in the list', () {
    final people = [
      Liker.fromJson(wire(username: 'quiet_fox', displayName: 'Quiet Fox')),
      Liker.fromJson(wire(username: 'loud_bear', displayName: 'Loud Bear')),
      Liker.fromJson(wire(username: 'deepak', displayName: 'Developer String')),
    ];

    test('an empty search leaves the list alone', () {
      expect(likersMatching(people, '   ').length, 3);
    });

    test('a handle is found part-way through', () {
      final found = likersMatching(people, 'fox');
      expect(found.single.person.username, 'quiet_fox');
    });

    test('the name works as well as the handle', () {
      final found = likersMatching(people, 'developer');
      expect(found.single.person.username, 'deepak');
    });

    test('case does not matter', () {
      expect(
        likersMatching(people, 'LOUD').single.person.username,
        'loud_bear',
      );
    });

    test('a name nobody has finds nobody', () {
      expect(likersMatching(people, 'zzz'), isEmpty);
    });
  });
}
