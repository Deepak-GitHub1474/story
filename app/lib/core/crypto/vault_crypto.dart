import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class KdfParams {
  const KdfParams({
    this.algo = 'argon2id',
    this.memoryKib = 65536,
    this.iterations = 3,
    this.parallelism = 4,
  });

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
    algo: json['algo'] as String? ?? 'argon2id',
    memoryKib: json['memory_kib'] as int? ?? 65536,
    iterations: json['iterations'] as int? ?? 3,
    parallelism: json['parallelism'] as int? ?? 4,
  );

  final String algo;
  final int memoryKib;
  final int iterations;
  final int parallelism;

  Map<String, dynamic> toJson() => {
    'algo': algo,
    'memory_kib': memoryKib,
    'iterations': iterations,
    'parallelism': parallelism,
  };
}

class VaultCrypto {
  const VaultCrypto();

  static const keyLength = 32;
  static const nonceLength = 12;
  static const saltLength = 16;
  static const chunkSize = 1024 * 1024;

  static const umkAadPrefix = 'story.umk.v1|';
  static const dekAadPrefix = 'story.dek.v1|';
  static const itemInfoPrefix = 'story.vault.item.v1|';
  static const labelInfo = 'story.vault.label.v1';

  AesGcm get _cipher => AesGcm.with256bits();

  Future<Uint8List> randomBytes(int length) async {
    final key = await _cipher.newSecretKey();
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes.take(length).toList());
  }

  Future<Uint8List> deriveKek(Uint8List secret, Uint8List salt, KdfParams params) async {
    final algorithm = Argon2id(
      memory: params.memoryKib,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: keyLength,
    );

    final key = await algorithm.deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<Uint8List> deriveItemKey({
    required Uint8List umk,
    required Uint8List kekPasscode,
    required Uint8List saltItem,
    required String itemId,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey([...umk, ...kekPasscode]),
      nonce: saltItem,
      info: utf8.encode('$itemInfoPrefix$itemId'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<Uint8List> wrap({
    required Uint8List key,
    required Uint8List plaintext,
    required String aad,
  }) async {
    final nonce = await randomBytes(nonceLength);
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: utf8.encode(aad),
    );
    return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> unwrap({
    required Uint8List key,
    required Uint8List sealed,
    required String aad,
  }) async {
    if (sealed.length < nonceLength + 16) {
      throw const FormatException('Ciphertext is too short to be valid.');
    }

    final nonce = sealed.sublist(0, nonceLength);
    final macStart = sealed.length - 16;
    final box = SecretBox(
      sealed.sublist(nonceLength, macStart),
      nonce: nonce,
      mac: Mac(sealed.sublist(macStart)),
    );

    final plaintext = await _cipher.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: utf8.encode(aad),
    );
    return Uint8List.fromList(plaintext);
  }

  Future<String> labelHash({required Uint8List umk, required String label}) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
    final labelKey = await hkdf.deriveKey(
      secretKey: SecretKey(umk),
      nonce: const <int>[],
      info: utf8.encode(labelInfo),
    );

    final mac = await Hmac.sha256().calculateMac(
      utf8.encode(normalizeLabel(label)),
      secretKey: labelKey,
    );
    return mac.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String normalizeLabel(String label) => label.trim();
}
