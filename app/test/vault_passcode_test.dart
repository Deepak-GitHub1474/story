import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/vault/data/vault_selection.dart';

void main() {
  group('the passcode is the only thing guarding the vault', () {
    test('a short one is refused', () {
      expect(isStrongPasscode('secret'), isFalse);
      expect(isStrongPasscode('123456'), isFalse);
    });

    test('a digit-only pin is refused however long', () {
      expect(isStrongPasscode('1234567890123'), isFalse);
    });

    test('a single repeated character is refused', () {
      expect(isStrongPasscode('aaaaaaaaaaaa'), isFalse);
    });

    test('a real passphrase is accepted', () {
      expect(isStrongPasscode('rusty gate summer'), isTrue);
      expect(isStrongPasscode('Th3-quiet-fox!'), isTrue);
    });

    test('surrounding space does not make a weak one strong', () {
      expect(isStrongPasscode('   short   '), isFalse);
    });

    test('the minimum is ten real characters', () {
      expect(isStrongPasscode('abcdefghi1'), isTrue);
      expect(isStrongPasscode('abcdefgh1'), isFalse);
    });
  });
}
