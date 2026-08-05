import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/crypto/vault_crypto.dart';
import 'package:story_app/features/vault/data/vault_transfer.dart';

const crypto = VaultCrypto();
final transfer = VaultTransfer(crypto, null);

Uint8List textLike(int length) => Uint8List.fromList(
  utf8.encode(List.filled(length ~/ 20, 'the quick brown fox ').join()),
);

Uint8List randomLike(int length) {
  final random = Random(20260805);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

void main() {
  test('a pdf is compressed before it is encrypted', () {
    final plain = textLike(4000);
    final packed = VaultTransfer.pack(plain, kind: 'pdf');

    expect(packed.compression, 'gzip');
    expect(packed.bytes.length, lessThan(plain.length));
  });

  test('unpacking a compressed payload gives back the original bytes', () {
    final plain = textLike(4000);
    final packed = VaultTransfer.pack(plain, kind: 'pdf');

    expect(VaultTransfer.unpack(packed.bytes, packed.compression), equals(plain));
  });

  test('an image is left alone because it is already compressed', () {
    final plain = randomLike(4000);
    final packed = VaultTransfer.pack(plain, kind: 'image');

    expect(packed.compression, 'none');
    expect(packed.bytes, equals(plain));
  });

  test('a video is left alone too', () {
    final packed = VaultTransfer.pack(randomLike(4000), kind: 'video');
    expect(packed.compression, 'none');
  });

  test('a pdf that does not shrink is stored as it is', () {
    final incompressible = randomLike(4000);
    final packed = VaultTransfer.pack(incompressible, kind: 'pdf');

    expect(packed.compression, 'none');
    expect(packed.bytes, equals(incompressible));
  });

  test('unpacking with none is a passthrough', () {
    final plain = randomLike(100);
    expect(VaultTransfer.unpack(plain, 'none'), equals(plain));
  });

  test('an empty file survives the round trip', () {
    final packed = VaultTransfer.pack(Uint8List(0), kind: 'pdf');
    expect(VaultTransfer.unpack(packed.bytes, packed.compression), isEmpty);
  });

  test('the encrypted metadata records how the payload was packed', () async {
    final umk = await crypto.randomBytes(VaultCrypto.keyLength);
    final passcodeKey = await crypto.randomBytes(VaultCrypto.keyLength);
    final plain = textLike(4000);

    final payload = await transfer.encrypt(
      plaintext: plain,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: 'vit_compress',
      metadata: {'filename': 'letter.pdf'},
      kind: 'pdf',
    );

    final metadata = await transfer.decryptMetadata(
      encryptedMetadata: payload.encryptedMetadata,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: 'vit_compress',
    );

    expect(metadata['compression'], 'gzip');
    expect(metadata['filename'], 'letter.pdf');
  });

  test('a compressed item decrypts back to the exact original', () async {
    final umk = await crypto.randomBytes(VaultCrypto.keyLength);
    final passcodeKey = await crypto.randomBytes(VaultCrypto.keyLength);
    final plain = textLike(8000);

    final payload = await transfer.encrypt(
      plaintext: plain,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: 'vit_round',
      metadata: {'filename': 'long.pdf'},
      kind: 'pdf',
    );

    final restored = await transfer.decrypt(
      ciphertext: payload.ciphertext,
      wrappedDek: payload.wrappedDek,
      saltItem: payload.saltItem,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: 'vit_round',
      compression: 'gzip',
    );

    expect(restored, equals(plain));
  });

  test('compression shrinks what actually leaves the device', () async {
    final umk = await crypto.randomBytes(VaultCrypto.keyLength);
    final passcodeKey = await crypto.randomBytes(VaultCrypto.keyLength);
    final plain = textLike(20000);

    final compressed = await transfer.encrypt(
      plaintext: plain,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: 'vit_a',
      metadata: const {},
      kind: 'pdf',
    );
    final raw = await transfer.encrypt(
      plaintext: plain,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: 'vit_b',
      metadata: const {},
      kind: 'image',
    );

    expect(compressed.ciphertext.length, lessThan(raw.ciphertext.length ~/ 2));
  });
}
