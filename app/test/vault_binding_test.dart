import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/crypto/vault_crypto.dart';
import 'package:story_app/features/vault/data/vault_transfer.dart';

void main() {
  const crypto = VaultCrypto();
  final transfer = VaultTransfer(crypto, null);

  final umk = Uint8List.fromList(List.generate(32, (i) => i));
  final passcodeKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));
  final plaintext = Uint8List.fromList(utf8.encode('the thing i kept'));

  test('a file stored in the vault opens again', () async {
    final payload = await transfer.encrypt(
      plaintext: plaintext,
      umk: umk,
      passcodeKey: passcodeKey,
      metadata: {'filename': 'note.png'},
    );

    final opened = await transfer.decrypt(
      ciphertext: payload.ciphertext,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
      passcodeKey: passcodeKey,
    );

    expect(utf8.decode(opened), 'the thing i kept');
  });

  test('one item cannot be opened with another item keys', () async {
    final mine = await transfer.encrypt(
      plaintext: plaintext,
      umk: umk,
      passcodeKey: passcodeKey,
      metadata: {'filename': 'note.png'},
    );
    final other = await transfer.encrypt(
      plaintext: plaintext,
      umk: umk,
      passcodeKey: passcodeKey,
      metadata: {'filename': 'other.png'},
    );

    expect(
      () => transfer.decrypt(
        ciphertext: mine.ciphertext,
        wrappedDek: other.wrappedDek,
        saltItem: other.saltItem,
        umk: umk,
        passcodeKey: passcodeKey,
      ),
      throwsA(anything),
    );
  });
}
