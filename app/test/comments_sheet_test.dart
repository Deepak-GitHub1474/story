import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/auth/models/auth_models.dart';
import 'package:story_app/features/auth/providers/auth_provider.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/providers/story_providers.dart';
import 'package:story_app/features/stories/widgets/comments_sheet.dart';
import 'package:story_app/theme/app_theme.dart';

const meId = 'usr_me';
const strangerId = 'usr_stranger';

AppUser signedInAs(String userId) => AppUser.fromJson({
  'user_id': userId,
  'username': 'deepak',
  'display_name': 'Developer String',
  'avatar_seed': 'seed',
  'role': 'user',
  'status': 'active',
});

class FakeAuth extends AuthNotifier {
  FakeAuth(this._userId);

  final String? _userId;

  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    user: _userId == null ? null : signedInAs(_userId),
  );
}

class FakeComments extends CommentsNotifier {
  FakeComments(this._comments);

  final List<Comment> _comments;

  @override
  Future<List<Comment>> build(String storyId) async => _comments;
}

Comment aComment({
  required String authorId,
  String username = 'deepak',
  bool mine = false,
}) => Comment(
  commentId: 'cm_1',
  storyId: 'st_1',
  parentId: null,
  author: StoryAuthor(
    userId: authorId,
    username: username,
    displayName: 'Developer String',
    avatarSeed: 'seed',
  ),
  body: 'A comment',
  likes: 0,
  replyCount: 0,
  isLiked: false,
  canDelete: mine,
  createdAt: DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 20))
      .toIso8601String(),
);

Future<void> showSheet(
  WidgetTester tester, {
  required Comment comment,
  String? storyAuthorId,
  String? viewerId = meId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => FakeAuth(viewerId)),
        commentsProvider.overrideWith(() => FakeComments([comment])),
      ],
      child: MaterialApp(
        theme: midnightTheme,
        home: Scaffold(
          body: CommentsSheet(storyId: 'st_1', storyAuthorId: storyAuthorId),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the writer can take down their own comment', (tester) async {
    await showSheet(tester, comment: aComment(authorId: meId));

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('the story author can take down a stranger\'s comment', (
    tester,
  ) async {
    await showSheet(
      tester,
      comment: aComment(authorId: strangerId, username: 'someone'),
      storyAuthorId: meId,
    );

    expect(
      find.text('Delete'),
      findsOneWidget,
      reason: 'my story, so I decide what stays under it',
    );
  });

  testWidgets('a reader gets no delete on someone else\'s story', (
    tester,
  ) async {
    await showSheet(
      tester,
      comment: aComment(authorId: strangerId, username: 'someone'),
      storyAuthorId: strangerId,
    );

    expect(find.text('Delete'), findsNothing);
    expect(find.text('Report'), findsNothing);
  });

  testWidgets('the author badge and the delete arrive together', (
    tester,
  ) async {
    await showSheet(
      tester,
      comment: aComment(authorId: meId),
      storyAuthorId: meId,
    );

    expect(find.text(' · Author'), findsOneWidget);
    expect(
      find.text('Delete'),
      findsOneWidget,
      reason: 'the badge proved the ids line up, so delete must be offered',
    );
  });

  testWidgets('when the app cannot tell, it lets the server decide', (
    tester,
  ) async {
    await showSheet(
      tester,
      comment: aComment(authorId: meId),
      storyAuthorId: meId,
      viewerId: null,
    );

    expect(
      find.text('Delete'),
      findsOneWidget,
      reason: 'hiding it on a hunch left the writer with no way to delete',
    );
  });

  testWidgets('the server flag alone is enough', (tester) async {
    await showSheet(
      tester,
      comment: aComment(authorId: strangerId, username: 'someone', mine: true),
      storyAuthorId: strangerId,
    );

    expect(find.text('Delete'), findsOneWidget);
  });
}
