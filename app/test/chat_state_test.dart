import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/chat/providers/chat_providers.dart';

void main() {
  test('an open chat with working keys can be typed in', () {
    expect(const ConversationState(isLoading: false).canSend, isTrue);
  });

  test('a chat whose keys changed cannot be typed in until it is reset', () {
    expect(
      const ConversationState(isLoading: false, needsRekey: true).canSend,
      isFalse,
    );
  });

  test('a chat still loading cannot be typed in', () {
    expect(const ConversationState().canSend, isFalse);
  });
}
