import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/models/story_models.dart';
import 'package:story_app/features/stories/widgets/comment_tile.dart';
import 'package:story_app/theme/app_theme.dart';

Comment aComment({
  String id = 'cm_1',
  String username = 'quiet_fox',
  String displayName = 'Quiet Fox',
  String userId = 'us_2',
  String body = 'This said what I could not.',
  int replyCount = 0,
  List<Comment> replies = const [],
  String? hoursAgo,
}) => Comment(
  commentId: id,
  storyId: 'st_1',
  parentId: null,
  author: StoryAuthor(
    userId: userId,
    username: username,
    displayName: displayName,
    avatarSeed: 'seed',
  ),
  body: body,
  likes: 0,
  replyCount: replyCount,
  isLiked: false,
  createdAt:
      hoursAgo ??
      DateTime.now().toUtc().subtract(const Duration(hours: 19)).toIso8601String(),
  replies: replies,
);

Future<void> showTile(
  WidgetTester tester,
  Comment comment, {
  String? storyAuthorId,
  bool isThreadOpen = false,
  VoidCallback? onToggleReplies,
  void Function(StoryAuthor)? onAuthorTap,
  String? viewerId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: midnightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CommentTile(
            comment: comment,
            viewerId: viewerId,
            storyAuthorId: storyAuthorId,
            isThreadOpen: isThreadOpen,
            onDelete: (_) {},
            onLike: (_) {},
            onReply: (_) {},
            onToggleReplies: onToggleReplies ?? () {},
            onAuthorTap: onAuthorTap,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder said(String words) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(words),
);

void main() {
  testWidgets('a comment is signed with the username, not the display name', (
    tester,
  ) async {
    await showTile(tester, aComment());

    expect(find.text('quiet_fox'), findsOneWidget);
    expect(find.text('Quiet Fox'), findsNothing);
  });

  testWidgets('the age sits beside the name, the words go below', (
    tester,
  ) async {
    await showTile(tester, aComment());

    final name = tester.getTopLeft(find.text('quiet_fox'));
    final age = tester.getTopLeft(find.text('19 hours ago'));
    final words = tester.getTopLeft(said('This said what I could not.'));

    expect(
      age.dy,
      closeTo(name.dy, 4),
      reason: 'name and time share a line',
    );
    expect(age.dx, greaterThan(name.dx));
    expect(words.dy, greaterThan(name.dy), reason: 'the comment sits under it');
  });

  testWidgets('the age is told the way a story tells it', (tester) async {
    await showTile(
      tester,
      aComment(
        hoursAgo: DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 3))
            .toIso8601String(),
      ),
    );

    expect(find.text('3 mins ago'), findsOneWidget);
  });

  testWidgets('the writer of the story is marked as the author', (
    tester,
  ) async {
    await showTile(tester, aComment(userId: 'us_1'), storyAuthorId: 'us_1');

    expect(find.text(' · Author'), findsOneWidget);
  });

  testWidgets('someone else is not marked as the author', (tester) async {
    await showTile(tester, aComment(userId: 'us_2'), storyAuthorId: 'us_1');

    expect(find.text(' · Author'), findsNothing);
  });

  testWidgets('replies stay folded until asked for', (tester) async {
    await showTile(
      tester,
      aComment(
        replyCount: 3,
        replies: [aComment(id: 'cm_2', username: 'someone', body: 'Hidden')],
      ),
    );

    expect(find.text('View 3 more replies'), findsOneWidget);
    expect(said('Hidden'), findsNothing);
  });

  testWidgets('one reply is counted in the singular', (tester) async {
    await showTile(tester, aComment(replyCount: 1));

    expect(find.text('View 1 more reply'), findsOneWidget);
  });

  testWidgets('an open thread offers to fold itself back', (tester) async {
    await showTile(
      tester,
      aComment(
        replyCount: 1,
        replies: [aComment(id: 'cm_2', username: 'someone', body: 'Shown now')],
      ),
      isThreadOpen: true,
    );

    expect(find.text('Hide replies'), findsOneWidget);
    expect(said('Shown now'), findsOneWidget);
  });

  testWidgets('the name and the face both lead to that person', (tester) async {
    final tapped = <String>[];
    await showTile(
      tester,
      aComment(),
      onAuthorTap: (author) => tapped.add(author.username!),
    );

    await tester.tap(find.text('quiet_fox'));
    await tester.pump();
    expect(tapped, ['quiet_fox']);
  });

  testWidgets('a story author can take down what was said on their story', (
    tester,
  ) async {
    await showTile(
      tester,
      aComment(userId: 'us_stranger'),
      storyAuthorId: 'us_me',
      viewerId: 'us_me',
    );

    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Report'), findsNothing);
  });

  testWidgets('my own reply under a stranger\'s comment is mine to delete', (
    tester,
  ) async {
    await showTile(
      tester,
      aComment(
        userId: 'us_stranger',
        username: 'someone',
        replyCount: 1,
        replies: [
          aComment(
            id: 'cm_2',
            userId: 'us_me',
            username: 'deepshri',
            body: 'My reply',
          ),
        ],
      ),
      storyAuthorId: 'us_stranger',
      viewerId: 'us_me',
      isThreadOpen: true,
    );

    expect(
      find.text('Delete'),
      findsOneWidget,
      reason: 'the reply is mine even though the comment above it is not',
    );
  });

  testWidgets('a reply by someone else on their story stays theirs', (
    tester,
  ) async {
    await showTile(
      tester,
      aComment(
        userId: 'us_stranger',
        username: 'someone',
        replyCount: 1,
        replies: [
          aComment(
            id: 'cm_2',
            userId: 'us_other',
            username: 'third_party',
            body: 'Their reply',
          ),
        ],
      ),
      storyAuthorId: 'us_stranger',
      viewerId: 'us_me',
      isThreadOpen: true,
    );

    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('the story author can take down a reply too', (tester) async {
    await showTile(
      tester,
      aComment(
        userId: 'us_stranger',
        username: 'someone',
        replyCount: 1,
        replies: [
          aComment(
            id: 'cm_2',
            userId: 'us_other',
            username: 'third_party',
            body: 'Their reply',
          ),
        ],
      ),
      storyAuthorId: 'us_me',
      viewerId: 'us_me',
      isThreadOpen: true,
    );

    expect(find.text('Delete'), findsNWidgets(2));
  });

  testWidgets('someone with no say over a comment is offered nothing', (
    tester,
  ) async {
    await showTile(
      tester,
      aComment(userId: 'us_stranger'),
      storyAuthorId: 'us_stranger',
      viewerId: 'us_me',
    );

    expect(find.text('Delete'), findsNothing);
    expect(
      find.text('Report'),
      findsNothing,
      reason: 'Report was wired to the delete call and kept losing comments',
    );
    expect(find.text('Reply'), findsOneWidget);
  });
}
