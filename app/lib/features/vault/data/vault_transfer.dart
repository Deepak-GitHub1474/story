import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/crypto/vault_crypto.dart';

class TransferProgress {
  const TransferProgress({required this.sent, required this.total});

  final int sent;
  final int total;

  double get fraction => total == 0 ? 0 : sent / total;
}

class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.wrappedDek,
    required this.saltItem,
    required this.encryptedMetadata,
    required this.chunkCount,
  });

  final Uint8List ciphertext;
  final Uint8List wrappedDek;
  final Uint8List saltItem;
  final Uint8List encryptedMetadata;
  final int chunkCount;
}

class VaultTransfer {
  const VaultTransfer(this._crypto, this._dio);

  final VaultCrypto _crypto;
  final Dio _dio;

  static int chunkCountFor(int length) =>
      (length / VaultCrypto.chunkSize).ceil().clamp(1, 100000);

  Future<EncryptedPayload> encrypt({
    required Uint8List plaintext,
    required Uint8List umk,
    required Uint8List passcodeKey,
    required String itemId,
    required Map<String, dynamic> metadata,
  }) async {
    final saltItem = await _crypto.randomBytes(VaultCrypto.saltLength);
    final dek = await _crypto.randomBytes(VaultCrypto.keyLength);

    final itemKey = await _crypto.deriveItemKey(
      umk: umk,
      kekPasscode: passcodeKey,
      saltItem: saltItem,
      itemId: itemId,
    );

    final wrappedDek = await _crypto.wrap(
      key: itemKey,
      plaintext: dek,
      aad: '${VaultCrypto.dekAadPrefix}$itemId',
    );

    final ciphertext = await _crypto.wrap(
      key: dek,
      plaintext: plaintext,
      aad: '${VaultCrypto.dekAadPrefix}$itemId',
    );

    final encryptedMetadata = await _crypto.wrap(
      key: dek,
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(metadata))),
      aad: '${VaultCrypto.dekAadPrefix}$itemId',
    );

    return EncryptedPayload(
      ciphertext: ciphertext,
      wrappedDek: wrappedDek,
      saltItem: saltItem,
      encryptedMetadata: encryptedMetadata,
      chunkCount: chunkCountFor(ciphertext.length),
    );
  }

  Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List wrappedDek,
    required Uint8List saltItem,
    required Uint8List umk,
    required Uint8List passcodeKey,
    required String itemId,
  }) async {
    final itemKey = await _crypto.deriveItemKey(
      umk: umk,
      kekPasscode: passcodeKey,
      saltItem: saltItem,
      itemId: itemId,
    );

    final dek = await _crypto.unwrap(
      key: itemKey,
      sealed: wrappedDek,
      aad: '${VaultCrypto.dekAadPrefix}$itemId',
    );

    return _crypto.unwrap(
      key: dek,
      sealed: ciphertext,
      aad: '${VaultCrypto.dekAadPrefix}$itemId',
    );
  }

  Future<Map<String, dynamic>> decryptMetadata({
    required Uint8List encryptedMetadata,
    required Uint8List wrappedDek,
    required Uint8List saltItem,
    required Uint8List umk,
    required Uint8List passcodeKey,
    required String itemId,
  }) async {
    final plaintext = await decrypt(
      ciphertext: encryptedMetadata,
      wrappedDek: wrappedDek,
      saltItem: saltItem,
      umk: umk,
      passcodeKey: passcodeKey,
      itemId: itemId,
    );
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(plaintext)) as Map);
  }

  Future<int> upload({
    required String url,
    required Uint8List ciphertext,
    void Function(TransferProgress)? onProgress,
  }) async {
    await _dio.put<void>(
      url,
      data: Stream.value(ciphertext),
      options: Options(
        headers: {'content-length': ciphertext.length},
        contentType: 'application/octet-stream',
      ),
      onSendProgress: (sent, total) =>
          onProgress?.call(TransferProgress(sent: sent, total: ciphertext.length)),
    );
    return ciphertext.length;
  }

  Future<Uint8List> download({
    required String url,
    void Function(TransferProgress)? onProgress,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) => onProgress?.call(
        TransferProgress(sent: received, total: total > 0 ? total : received),
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}
