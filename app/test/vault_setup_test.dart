import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/vault/data/vault_setup.dart';

void main() {
  test('a passcode identical to the account password is refused', () {
    expect(
      validatePasscode(passcode: 'same-secret-here', password: 'same-secret-here'),
      VaultSetupError.sameAsPassword,
    );
  });

  test('case and spacing do not get you around it', () {
    expect(
      validatePasscode(passcode: '  Same-Secret-Here ', password: 'same-secret-here'),
      VaultSetupError.sameAsPassword,
    );
  });

  test('a short passcode is refused', () {
    expect(
      validatePasscode(passcode: 'short', password: 'a-different-password'),
      VaultSetupError.tooShort,
    );
  });

  test('an empty passcode is refused', () {
    expect(
      validatePasscode(passcode: '', password: 'a-different-password'),
      VaultSetupError.tooShort,
    );
  });

  test('a distinct long passcode is accepted', () {
    expect(
      validatePasscode(passcode: 'my-vault-passcode', password: 'my-account-password'),
      isNull,
    );
  });

  test('a passcode that merely contains the password is still allowed', () {
    expect(
      validatePasscode(passcode: 'my-passwordly-thing', password: 'my-password'),
      isNull,
    );
  });

  test('the error message names what to change', () {
    expect(
      messageFor(VaultSetupError.sameAsPassword),
      contains('different'),
    );
    expect(messageFor(VaultSetupError.tooShort), contains('8'));
  });
}
