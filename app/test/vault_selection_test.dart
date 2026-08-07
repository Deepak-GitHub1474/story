import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/vault/data/vault_selection.dart';
import 'package:story_app/features/vault/models/vault_models.dart';

VaultPasscode vault(String id, String label, {String scope = 'vault'}) =>
    VaultPasscode.fromJson({
      'passcode_id': id,
      'label': label,
      'scope': scope,
      'salt_pc': 'c2FsdA==',
      'kdf': const <String, dynamic>{},
    });

void main() {
  test('with nothing set up there is no vault to open', () {
    expect(selectVault(const [], null), isNull);
  });

  test('one vault opens without being asked which', () {
    final only = vault('pc_1', 'Main vault');
    expect(selectVault([only], null)?.passcodeId, 'pc_1');
  });

  test('the vault you picked is the vault you get', () {
    final vaults = [vault('pc_1', 'Papers'), vault('pc_2', 'Pictures')];
    expect(selectVault(vaults, 'pc_2')?.label, 'Pictures');
  });

  test('a vault id that is not yours opens nothing', () {
    final vaults = [vault('pc_1', 'Papers')];
    expect(selectVault(vaults, 'pc_9'), isNull);
  });

  test('a per-item passcode is not a vault you can open', () {
    final vaults = [vault('pc_1', 'One photo', scope: 'item')];
    expect(selectVault(vaults, null), isNull);
    expect(selectVault(vaults, 'pc_1'), isNull);
  });

  test('only the vaults are offered as vaults', () {
    final all = [
      vault('pc_1', 'One photo', scope: 'item'),
      vault('pc_2', 'Papers'),
      vault('pc_3', 'Pictures'),
    ];
    expect(vaultsOnly(all).map((row) => row.label), ['Papers', 'Pictures']);
  });

  test('with an item passcode first the first real vault still opens', () {
    final all = [vault('pc_1', 'One photo', scope: 'item'), vault('pc_2', 'Papers')];
    expect(selectVault(all, null)?.label, 'Papers');
  });

  test('a second vault can be made once the account already has keys', () {
    expect(canCreateVault(hasKeys: true, password: ''), isTrue);
  });

  test('the first vault cannot be made without the account password', () {
    expect(canCreateVault(hasKeys: false, password: ''), isFalse);
  });

  test('blank space is not an account password', () {
    expect(canCreateVault(hasKeys: false, password: '   '), isFalse);
  });

  test('the first vault can be made with the account password', () {
    expect(canCreateVault(hasKeys: false, password: 'a-long-password'), isTrue);
  });
}
