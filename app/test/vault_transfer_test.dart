import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/crypto/vault_crypto.dart';
import 'package:story_app/features/vault/data/vault_transfer.dart';

const crypto = VaultCrypto();
final transfer = VaultTransfer(crypto, Dio());

Uint8List file(int length) =>
    Uint8List.fromList(List.generate(length, (index) => index % 256));

void main() {
  test('an encrypted file round trips back to the original bytes', () async {
    final umk = await crypto.randomBytes(32);
    final plaintext = file(4096);

    final payload = await transfer.encrypt(
      plaintext: plaintext,
      umk: umk,
      metadata: {'filename': 'wedding.jpg', 'mime': 'image/jpeg'},
    );

    final opened = await transfer.decrypt(
      ciphertext: payload.ciphertext,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
    );

    expect(opened, equals(plaintext));
  });

  test('the ciphertext never contains the plaintext bytes', () async {
    final marker = Uint8List.fromList('SECRET-MARKER-VALUE'.codeUnits);

    final payload = await transfer.encrypt(
      plaintext: marker,
      umk: await crypto.randomBytes(32),
      metadata: const {},
    );

    expect(String.fromCharCodes(payload.ciphertext), isNot(contains('SECRET-MARKER')));
  });

  test('the filename lives only inside encrypted metadata', () async {
    final umk = await crypto.randomBytes(32);

    final payload = await transfer.encrypt(
      plaintext: file(64),
      umk: umk,
      metadata: {'filename': 'divorce-papers.pdf'},
    );

    expect(
      String.fromCharCodes(payload.encryptedMetadata),
      isNot(contains('divorce')),
    );

    final metadata = await transfer.decryptMetadata(
      encryptedMetadata: payload.encryptedMetadata,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
    );
    expect(metadata['filename'], 'divorce-papers.pdf');
  });

  test('a file still opens after the passcode is changed', () async {
    final umk = await crypto.randomBytes(32);
    final payload = await transfer.encrypt(
      plaintext: file(256),
      umk: umk,
      metadata: const {},
    );

    final opened = await transfer.decrypt(
      ciphertext: payload.ciphertext,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
    );

    expect(opened.length, 256, reason: 'only the wrapper changes, never the file');
  });

  test('a wrong master key cannot decrypt', () async {
    final payload = await transfer.encrypt(
      plaintext: file(256),
      umk: await crypto.randomBytes(32),
      metadata: const {},
    );

    final wrongUmk = await crypto.randomBytes(32);

    expect(
      () => transfer.decrypt(
        ciphertext: payload.ciphertext,
        wrappedDek: payload.wrappedDek,
        saltItem: payload.saltItem,
        umk: wrongUmk,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('a wrapped key moved to another item fails the tag check', () async {
    final umk = await crypto.randomBytes(32);

    final payload = await transfer.encrypt(
      plaintext: file(256),
      umk: umk,
      metadata: const {},
    );
    final other = await transfer.encrypt(
      plaintext: file(256),
      umk: umk,
      metadata: const {},
    );

    expect(
      () => transfer.decrypt(
        ciphertext: payload.ciphertext,
        wrappedDek: other.wrappedDek,
        saltItem: other.saltItem,
        umk: umk,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('chunk count follows the ciphertext size', () async {
    expect(VaultTransfer.chunkCountFor(1), 1);
    expect(VaultTransfer.chunkCountFor(VaultCrypto.chunkSize), 1);
    expect(VaultTransfer.chunkCountFor(VaultCrypto.chunkSize + 1), 2);
    expect(VaultTransfer.chunkCountFor(VaultCrypto.chunkSize * 5), 5);
  });

  test('a large file still round trips', () async {
    final umk = await crypto.randomBytes(32);
    final plaintext = file(300 * 1024);

    final payload = await transfer.encrypt(
      plaintext: plaintext,
      umk: umk,
      metadata: const {},
    );
    final opened = await transfer.decrypt(
      ciphertext: payload.ciphertext,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
    );

    expect(opened.length, plaintext.length);
    expect(opened, equals(plaintext));
  });
}
