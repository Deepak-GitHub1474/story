import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/widgets/comment_composer.dart';
import 'package:story_app/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: midnightTheme,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('the send button wakes up as soon as there are words', (tester) async {
    final controller = TextEditingController();
    var sent = 0;

    await tester.pumpWidget(
      _wrap(
        CommentComposer(
          controller: controller,
          isSending: false,
          onSend: () => sent += 1,
          replyingTo: null,
          onCancelReply: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sent, 0);

    await tester.enterText(find.byType(TextField), 'a kind thing');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sent, 1);
  });

  testWidgets('spaces alone do not wake it', (tester) async {
    final controller = TextEditingController();
    var sent = 0;

    await tester.pumpWidget(
      _wrap(
        CommentComposer(
          controller: controller,
          isSending: false,
          onSend: () => sent += 1,
          replyingTo: null,
          onCancelReply: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '    ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(sent, 0);
  });

  testWidgets('tapping an emoji is enough to send', (tester) async {
    final controller = TextEditingController();
    var sent = 0;

    await tester.pumpWidget(
      _wrap(
        CommentComposer(
          controller: controller,
          isSending: false,
          onSend: () => sent += 1,
          replyingTo: null,
          onCancelReply: () {},
        ),
      ),
    );

    await tester.tap(find.text(CommentComposer.quickEmoji.first));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(sent, 1);
  });
}
