import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/crypto/vault_crypto.dart';

const crypto = VaultCrypto();

const fastKdf = KdfParams(memoryKib: 8192, iterations: 1, parallelism: 1);

Uint8List bytes(String value) => Uint8List.fromList(utf8.encode(value));

void main() {
  test('random bytes are the requested length', () async {
    expect((await crypto.randomBytes(32)).length, 32);
  });

  test('random bytes differ between calls', () async {
    final first = await crypto.randomBytes(32);
    final second = await crypto.randomBytes(32);
    expect(first, isNot(equals(second)));
  });

  test('the same password and salt derive the same key', () async {
    final salt = bytes('0123456789abcdef');
    final a = await crypto.deriveKek(bytes('a-long-password'), salt, fastKdf);
    final b = await crypto.deriveKek(bytes('a-long-password'), salt, fastKdf);
    expect(a, equals(b));
  });

  test('a different password derives a different key', () async {
    final salt = bytes('0123456789abcdef');
    final a = await crypto.deriveKek(bytes('a-long-password'), salt, fastKdf);
    final b = await crypto.deriveKek(bytes('other-password!'), salt, fastKdf);
    expect(a, isNot(equals(b)));
  });

  test('a different salt derives a different key', () async {
    final a = await crypto.deriveKek(
      bytes('a-long-password'),
      bytes('0123456789abcdef'),
      fastKdf,
    );
    final b = await crypto.deriveKek(
      bytes('a-long-password'),
      bytes('fedcba9876543210'),
      fastKdf,
    );
    expect(a, isNot(equals(b)));
  });

  test('a wrapped key round trips', () async {
    final key = await crypto.randomBytes(32);
    final umk = await crypto.randomBytes(32);

    final sealed = await crypto.wrap(
      key: key,
      plaintext: umk,
      aad: '${VaultCrypto.umkAadPrefix}usr_1',
    );
    final opened = await crypto.unwrap(
      key: key,
      sealed: sealed,
      aad: '${VaultCrypto.umkAadPrefix}usr_1',
    );

    expect(opened, equals(umk));
  });

  test('the ciphertext never contains the plaintext', () async {
    final key = await crypto.randomBytes(32);
    final secret = bytes('the-master-key-value-here-padded');

    final sealed = await crypto.wrap(key: key, plaintext: secret, aad: 'x');
    expect(sealed.length, greaterThan(secret.length));
    expect(String.fromCharCodes(sealed), isNot(contains('master-key')));
  });

  test('wrapping twice produces different ciphertext', () async {
    final key = await crypto.randomBytes(32);
    final secret = await crypto.randomBytes(32);

    final first = await crypto.wrap(key: key, plaintext: secret, aad: 'x');
    final second = await crypto.wrap(key: key, plaintext: secret, aad: 'x');
    expect(first, isNot(equals(second)));
  });

  test('a wrong key cannot unwrap', () async {
    final key = await crypto.randomBytes(32);
    final wrong = await crypto.randomBytes(32);
    final sealed = await crypto.wrap(
      key: key,
      plaintext: await crypto.randomBytes(32),
      aad: 'x',
    );

    expect(
      () => crypto.unwrap(key: wrong, sealed: sealed, aad: 'x'),
      throwsA(isA<Exception>()),
    );
  });

  test('a wrapped key from another item fails the aad check', () async {
    final key = await crypto.randomBytes(32);
    final sealed = await crypto.wrap(
      key: key,
      plaintext: await crypto.randomBytes(32),
      aad: '${VaultCrypto.dekAadPrefix}vit_1',
    );

    expect(
      () => crypto.unwrap(
        key: key,
        sealed: sealed,
        aad: '${VaultCrypto.dekAadPrefix}vit_2',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('tampered ciphertext is rejected', () async {
    final key = await crypto.randomBytes(32);
    final sealed = await crypto.wrap(
      key: key,
      plaintext: await crypto.randomBytes(32),
      aad: 'x',
    );
    sealed[sealed.length - 1] ^= 0xFF;

    expect(
      () => crypto.unwrap(key: key, sealed: sealed, aad: 'x'),
      throwsA(isA<Exception>()),
    );
  });

  test('an item key needs both halves', () async {
    final umk = await crypto.randomBytes(32);
    final passcodeKey = await crypto.randomBytes(32);
    final salt = await crypto.randomBytes(16);

    final correct = await crypto.deriveItemKey(
      umk: umk,
      kekPasscode: passcodeKey,
      saltItem: salt,
      itemId: 'vit_1',
    );
    final withoutUmk = await crypto.deriveItemKey(
      umk: await crypto.randomBytes(32),
      kekPasscode: passcodeKey,
      saltItem: salt,
      itemId: 'vit_1',
    );
    final withoutPasscode = await crypto.deriveItemKey(
      umk: umk,
      kekPasscode: await crypto.randomBytes(32),
      saltItem: salt,
      itemId: 'vit_1',
    );

    expect(correct, isNot(equals(withoutUmk)));
    expect(correct, isNot(equals(withoutPasscode)));
  });

  test('two items with the same secrets get different keys', () async {
    final umk = await crypto.randomBytes(32);
    final passcodeKey = await crypto.randomBytes(32);
    final salt = await crypto.randomBytes(16);

    final first = await crypto.deriveItemKey(
      umk: umk,
      kekPasscode: passcodeKey,
      saltItem: salt,
      itemId: 'vit_1',
    );
    final second = await crypto.deriveItemKey(
      umk: umk,
      kekPasscode: passcodeKey,
      saltItem: salt,
      itemId: 'vit_2',
    );

    expect(first, isNot(equals(second)));
  });

  test('a label hash is deterministic for one master key', () async {
    final umk = await crypto.randomBytes(32);
    final a = await crypto.labelHash(umk: umk, label: 'Wedding photos');
    final b = await crypto.labelHash(umk: umk, label: 'Wedding photos');
    expect(a, equals(b));
  });

  test('a label hash normalises case and spacing', () async {
    final umk = await crypto.randomBytes(32);
    final a = await crypto.labelHash(umk: umk, label: 'Wedding Photos');
    final b = await crypto.labelHash(umk: umk, label: '  wedding   photos ');
    expect(a, equals(b));
  });

  test('the same label under a different master key hashes differently', () async {
    final a = await crypto.labelHash(
      umk: await crypto.randomBytes(32),
      label: 'Wedding photos',
    );
    final b = await crypto.labelHash(
      umk: await crypto.randomBytes(32),
      label: 'Wedding photos',
    );
    expect(a, isNot(equals(b)));
  });

  test('a label hash never contains the label', () async {
    final umk = await crypto.randomBytes(32);
    final hash = await crypto.labelHash(umk: umk, label: 'wedding');
    expect(hash, isNot(contains('wedding')));
    expect(hash.length, 64);
  });
}
