import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/chat/providers/chat_providers.dart';

void main() {
  test('an open chat with working keys can be typed in', () {
    expect(
      const ConversationState(isLoading: false, hasKey: true).canSend,
      isTrue,
    );
  });

  test('a chat whose keys changed cannot be typed in until it is reset', () {
    expect(
      const ConversationState(
        isLoading: false,
        hasKey: true,
        needsRekey: true,
      ).canSend,
      isFalse,
    );
  });

  test('a chat still loading cannot be typed in', () {
    expect(const ConversationState().canSend, isFalse);
  });

  test('a chat with no key of mine cannot be typed in', () {
    expect(
      const ConversationState(isLoading: false).canSend,
      isFalse,
      reason: 'anything typed would be dropped on the floor',
    );
  });

  test('the reset notice survives the next update', () {
    const stuck = ConversationState(
      isLoading: false,
      needsRekey: true,
      error: 'The keys for this chat changed.',
    );

    final later = stuck.copyWith(isSending: false);

    expect(later.needsRekey, isTrue);
    expect(later.error, 'The keys for this chat changed.');
  });

  test('the notice goes when the chat is asked to clear it', () {
    const stuck = ConversationState(
      isLoading: false,
      needsRekey: true,
      error: 'The keys for this chat changed.',
    );

    final fresh = stuck.copyWith(needsRekey: false, clearError: true);

    expect(fresh.needsRekey, isFalse);
    expect(fresh.error, isNull);
  });

  test('a chat that got its key back can be typed in', () {
    const stuck = ConversationState(isLoading: false, needsRekey: true);

    expect(stuck.copyWith(hasKey: true, needsRekey: false).canSend, isTrue);
  });
}
