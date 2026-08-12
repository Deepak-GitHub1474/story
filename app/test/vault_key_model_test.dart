import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/crypto/vault_crypto.dart';
import 'package:story_app/features/vault/data/vault_transfer.dart';
import 'package:story_app/features/vault/models/vault_models.dart';

const crypto = VaultCrypto();

String masterAad(String userId) => '${VaultCrypto.umkAadPrefix}$userId';

String vaultAad(String userId, String saltPc) =>
    '${VaultCrypto.umkAadPrefix}$userId|$saltPc';

Future<Uint8List> kekFor(String passcode, Uint8List salt) => crypto.deriveKek(
  Uint8List.fromList(utf8.encode(passcode)),
  salt,
  const KdfParams(memoryKib: 8192, iterations: 1),
);

void main() {
  group('a vault carries its own key', () {
    test('one vault passcode cannot open another vault', () async {
      const userId = 'usr_1';
      final saltA = await crypto.randomBytes(16);
      final saltB = await crypto.randomBytes(16);
      final umkB = await crypto.randomBytes(32);

      final sealedB = await crypto.wrap(
        key: await kekFor('the quiet fox', saltB),
        plaintext: umkB,
        aad: vaultAad(userId, base64Encode(saltB)),
      );

      final wrongKey = await kekFor('rusty gate summer', saltA);

      expect(
        () => crypto.unwrap(
          key: wrongKey,
          sealed: sealedB,
          aad: vaultAad(userId, base64Encode(saltB)),
        ),
        throwsA(anything),
      );
    });

    test('a key moved into another vault will not open', () async {
      const userId = 'usr_1';
      final salt = await crypto.randomBytes(16);
      final elsewhere = await crypto.randomBytes(16);
      final umk = await crypto.randomBytes(32);
      final kek = await kekFor('rusty gate summer', salt);

      final sealed = await crypto.wrap(
        key: kek,
        plaintext: umk,
        aad: vaultAad(userId, base64Encode(salt)),
      );

      expect(
        () => crypto.unwrap(
          key: kek,
          sealed: sealed,
          aad: vaultAad(userId, base64Encode(elsewhere)),
        ),
        throwsA(anything),
        reason: 'the salt is bound into the sealed key',
      );
    });

    test('another persons master key cannot open yours', () async {
      final salt = await crypto.randomBytes(16);
      final umk = await crypto.randomBytes(32);
      final kek = await kekFor('rusty gate summer', salt);

      final sealed = await crypto.wrap(
        key: kek,
        plaintext: umk,
        aad: masterAad('usr_1'),
      );

      expect(
        () => crypto.unwrap(key: kek, sealed: sealed, aad: masterAad('usr_2')),
        throwsA(anything),
      );
    });
  });

  group('changing a passcode leaves the files alone', () {
    test('the same file opens under a re-wrapped key', () async {
      final transfer = VaultTransfer(crypto, null);
      final umk = await crypto.randomBytes(32);
      final plaintext = Uint8List.fromList(utf8.encode('the thing i kept'));

      final payload = await transfer.encrypt(
        plaintext: plaintext,
        umk: umk,
        metadata: const {'filename': 'note.png'},
      );

      final oldSalt = await crypto.randomBytes(16);
      final newSalt = await crypto.randomBytes(16);
      final sealedOld = await crypto.wrap(
        key: await kekFor('rusty gate summer', oldSalt),
        plaintext: umk,
        aad: masterAad('usr_1'),
      );
      final recovered = await crypto.unwrap(
        key: await kekFor('rusty gate summer', oldSalt),
        sealed: sealedOld,
        aad: masterAad('usr_1'),
      );
      final sealedNew = await crypto.wrap(
        key: await kekFor('a whole new phrase', newSalt),
        plaintext: recovered,
        aad: masterAad('usr_1'),
      );
      final afterChange = await crypto.unwrap(
        key: await kekFor('a whole new phrase', newSalt),
        sealed: sealedNew,
        aad: masterAad('usr_1'),
      );

      final opened = await transfer.decrypt(
        ciphertext: payload.ciphertext,
        wrappedDek: payload.wrappedDek,
        saltItem: payload.saltItem,
        umk: afterChange,
      );

      expect(utf8.decode(opened), 'the thing i kept');
      expect(afterChange, equals(umk), reason: 'the vault key never changes');
    });

    test('the old passcode stops working', () async {
      final salt = await crypto.randomBytes(16);
      final umk = await crypto.randomBytes(32);

      final sealed = await crypto.wrap(
        key: await kekFor('a whole new phrase', salt),
        plaintext: umk,
        aad: masterAad('usr_1'),
      );

      final oldKey = await kekFor('rusty gate summer', salt);

      expect(
        () => crypto.unwrap(key: oldKey, sealed: sealed, aad: masterAad('usr_1')),
        throwsA(anything),
      );
    });
  });

  group('the vault record says which key it uses', () {
    test('a vault with no key of its own falls back to the main one', () {
      final vault = VaultPasscode.fromJson({
        'passcode_id': 'pcd_1',
        'label': 'Main vault',
        'salt_pc': 'c2FsdA==',
        'kdf': const <String, dynamic>{},
      });

      expect(vault.keySource, 'master');
      expect(vault.hasOwnKey, isFalse);
    });

    test('a separate vault is recognised by its own key', () {
      final vault = VaultPasscode.fromJson({
        'passcode_id': 'pcd_2',
        'label': 'Private things',
        'salt_pc': 'c2FsdA==',
        'kdf': const <String, dynamic>{},
        'key_source': 'own',
        'wrapped_umk': 'd3JhcHBlZA==',
      });

      expect(vault.hasOwnKey, isTrue);
      expect(vault.wrappedUmk, 'd3JhcHBlZA==');
    });
  });
}
