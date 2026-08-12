import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/vault_crypto.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/vault_repository.dart';
import '../data/vault_selection.dart';
import '../data/vault_transfer.dart';
import '../models/vault_models.dart';

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(ref.watch(apiClientProvider)),
);

const vaultMaxBytes = 10 * 1024 * 1024;

final vaultCryptoProvider = Provider<VaultCrypto>((ref) => const VaultCrypto());

final vaultTransferProvider = Provider<VaultTransfer>(
  (ref) => VaultTransfer(ref.watch(vaultCryptoProvider), Dio()),
);

final vaultOverviewProvider = FutureProvider<VaultOverview?>((ref) async {
  final result = await ref.watch(vaultRepositoryProvider).overview();
  return result.valueOrNull;
});

enum VaultLockState { locked, unlocked, needsSetup }

class VaultSession {
  const VaultSession({
    required this.state,
    this.umk,
    this.passcodeId,
    this.label,
    this.keySource,
    this.error,
  });

  final VaultLockState state;
  final Uint8List? umk;
  final String? passcodeId;
  final String? label;
  final String? keySource;
  final String? error;

  bool get isUnlocked => state == VaultLockState.unlocked && umk != null;

  VaultSession copyWith({String? label, String? error}) => VaultSession(
    state: state,
    umk: umk,
    passcodeId: passcodeId,
    label: label ?? this.label,
    keySource: keySource,
    error: error,
  );
}

final vaultSessionProvider = NotifierProvider<VaultSessionNotifier, VaultSession>(
  VaultSessionNotifier.new,
);

class VaultSessionNotifier extends Notifier<VaultSession> {
  @override
  VaultSession build() => const VaultSession(state: VaultLockState.locked);

  VaultCrypto get _crypto => ref.read(vaultCryptoProvider);

  VaultRepository get _repository => ref.read(vaultRepositoryProvider);

  String _umkAad(String userId) => '${VaultCrypto.umkAadPrefix}$userId';

  String _vaultAad(String userId, String saltPc) =>
      '${VaultCrypto.umkAadPrefix}$userId|$saltPc';

  Future<Uint8List?> _openMaster(String passcode, String userId) async {
    final keys = (await _repository.keys()).valueOrNull;
    if (keys == null) return null;

    final kek = await _crypto.deriveKek(
      Uint8List.fromList(utf8.encode(passcode)),
      Uint8List.fromList(base64Decode(keys.saltPw)),
      KdfParams.fromJson(keys.kdf),
    );

    try {
      return await _crypto.unwrap(
        key: kek,
        sealed: Uint8List.fromList(base64Decode(keys.wrappedUmk)),
        aad: _umkAad(userId),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _createMaster(String passcode, Uint8List umk, String userId) async {
    final salt = await _crypto.randomBytes(VaultCrypto.saltLength);
    const kdf = KdfParams();

    final kek = await _crypto.deriveKek(
      Uint8List.fromList(utf8.encode(passcode)),
      salt,
      kdf,
    );
    final wrapped = await _crypto.wrap(
      key: kek,
      plaintext: umk,
      aad: _umkAad(userId),
    );

    final result = await _repository.initKeys(
      saltPw: base64Encode(salt),
      wrappedUmk: base64Encode(wrapped),
      kdf: kdf.toJson(),
    );

    if (!result.isSuccess) {
      state = state.copyWith(error: result.failureOrNull!.message);
      return false;
    }
    return true;
  }

  Future<bool> createVault({
    required String label,
    required String passcode,
  }) async {
    if (!isStrongPasscode(passcode)) return false;

    final userId = ref.read(authProvider).user?.userId ?? '';
    const kdf = KdfParams();
    final saltPc = await _crypto.randomBytes(VaultCrypto.saltLength);

    final hasMaster = (await _repository.keys()).valueOrNull != null;
    var keySource = 'master';
    String? wrappedUmk;

    if (!hasMaster) {
      final umk = await _crypto.randomBytes(VaultCrypto.keyLength);
      if (!await _createMaster(passcode, umk, userId)) return false;
    } else if (await _openMaster(passcode, userId) == null) {
      final umk = await _crypto.randomBytes(VaultCrypto.keyLength);
      final kek = await _crypto.deriveKek(
        Uint8List.fromList(utf8.encode(passcode)),
        saltPc,
        kdf,
      );
      final sealed = await _crypto.wrap(
        key: kek,
        plaintext: umk,
        aad: _vaultAad(userId, base64Encode(saltPc)),
      );
      keySource = 'own';
      wrappedUmk = base64Encode(sealed);
    }

    final result = await _repository.createPasscode(
      label: label,
      saltPc: base64Encode(saltPc),
      kdf: kdf.toJson(),
      keySource: keySource,
      wrappedUmk: wrappedUmk,
    );

    if (result.valueOrNull == null) {
      state = state.copyWith(error: result.failureOrNull?.message);
      return false;
    }
    return true;
  }

  Future<bool> unlock({
    required String passcode,
    String? passcodeId,
  }) async {
    final userId = ref.read(authProvider).user?.userId ?? '';

    final overview = await _repository.overview();
    final record = selectVault(
      overview.valueOrNull?.passcodes ?? const [],
      passcodeId,
    );
    if (record == null) {
      state = const VaultSession(state: VaultLockState.needsSetup);
      return false;
    }

    Uint8List? umk;
    if (record.hasOwnKey) {
      final kek = await _crypto.deriveKek(
        Uint8List.fromList(utf8.encode(passcode)),
        Uint8List.fromList(base64Decode(record.saltPc)),
        KdfParams.fromJson(record.kdf),
      );
      try {
        umk = await _crypto.unwrap(
          key: kek,
          sealed: Uint8List.fromList(base64Decode(record.wrappedUmk!)),
          aad: _vaultAad(userId, record.saltPc),
        );
      } catch (_) {
        umk = null;
      }
    } else {
      umk = await _openMaster(passcode, userId);
    }

    if (umk == null) {
      state = const VaultSession(
        state: VaultLockState.locked,
        error: 'That passcode did not open this vault.',
      );
      return false;
    }

    state = VaultSession(
      state: VaultLockState.unlocked,
      umk: umk,
      passcodeId: record.passcodeId,
      label: record.label,
      keySource: record.keySource,
    );
    return true;
  }

  void lock() {
    state = const VaultSession(state: VaultLockState.locked);
  }

  Future<bool> changePasscode(String newPasscode) async {
    final session = state;
    final umk = session.umk;
    if (umk == null || !isStrongPasscode(newPasscode)) return false;

    final userId = ref.read(authProvider).user?.userId ?? '';
    const kdf = KdfParams();
    final salt = await _crypto.randomBytes(VaultCrypto.saltLength);
    final isOwn = session.keySource == 'own';

    final kek = await _crypto.deriveKek(
      Uint8List.fromList(utf8.encode(newPasscode)),
      salt,
      kdf,
    );
    final sealed = await _crypto.wrap(
      key: kek,
      plaintext: umk,
      aad: isOwn ? _vaultAad(userId, base64Encode(salt)) : _umkAad(userId),
    );

    final result = isOwn
        ? await _repository.changeVaultKey(
            passcodeId: session.passcodeId!,
            saltPc: base64Encode(salt),
            wrappedUmk: base64Encode(sealed),
            kdf: kdf.toJson(),
          )
        : await _repository.changeMasterKey(
            saltPw: base64Encode(salt),
            wrappedUmk: base64Encode(sealed),
            kdf: kdf.toJson(),
          );

    if (!result.isSuccess) {
      state = state.copyWith(error: result.failureOrNull?.message);
      return false;
    }
    return true;
  }

  Future<bool> renameVault({
    required String passcodeId,
    required String label,
  }) async {
    final result = await _repository.renameVault(
      passcodeId: passcodeId,
      label: label,
    );

    if (result.valueOrNull == null) {
      state = state.copyWith(error: result.failureOrNull?.message);
      return false;
    }

    if (state.passcodeId == passcodeId) state = state.copyWith(label: label);
    return true;
  }

  Future<bool> deleteVault(String passcodeId) async {
    final result = await _repository.deleteVault(passcodeId);
    if (!result.isSuccess) {
      state = state.copyWith(error: result.failureOrNull?.message);
      return false;
    }

    if (state.passcodeId == passcodeId) lock();
    return true;
  }

  Future<String?> hashLabel(String label) async {
    final umk = state.umk;
    if (umk == null) return null;
    return _crypto.labelHash(umk: umk, label: label);
  }
}

final vaultItemsProvider = FutureProvider<List<VaultItem>>((ref) async {
  final session = ref.watch(vaultSessionProvider);
  if (!session.isUnlocked) return const [];

  final result = await ref
      .watch(vaultRepositoryProvider)
      .items(passcodeId: session.passcodeId);
  return result.valueOrNull ?? const [];
});


enum UploadStage { idle, packing, encrypting, sending, finishing, failed }

class VaultUploadState {
  const VaultUploadState({
    this.progress = 0,
    this.isBusy = false,
    this.error,
    this.stage = UploadStage.idle,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.filename,
  });

  final double progress;
  final bool isBusy;
  final String? error;
  final UploadStage stage;
  final int sentBytes;
  final int totalBytes;
  final String? filename;

  bool get canRetry => stage == UploadStage.failed;

  VaultUploadState copyWith({
    double? progress,
    bool? isBusy,
    String? error,
    UploadStage? stage,
    int? sentBytes,
    int? totalBytes,
    String? filename,
  }) => VaultUploadState(
    progress: progress ?? this.progress,
    isBusy: stage == UploadStage.failed ? false : (isBusy ?? this.isBusy),
    error: stage == UploadStage.failed ? (error ?? this.error) : error,
    stage: stage ?? this.stage,
    sentBytes: sentBytes ?? this.sentBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    filename: filename ?? this.filename,
  );

  String get label => switch (stage) {
    UploadStage.packing => 'Preparing',
    UploadStage.encrypting => 'Encrypting on this device',
    UploadStage.sending => 'Uploading',
    UploadStage.finishing => 'Finishing',
    UploadStage.failed => 'Upload failed',
    UploadStage.idle => '',
  };
}

final vaultUploadProvider = NotifierProvider<VaultUploadNotifier, VaultUploadState>(
  VaultUploadNotifier.new,
);

class VaultUploadNotifier extends Notifier<VaultUploadState> {
  ({Uint8List bytes, String filename, String kind, String? label})? _last;

  Future<bool> retry() async {
    final again = _last;
    if (again == null) return false;

    return addFile(
      bytes: again.bytes,
      filename: again.filename,
      kind: again.kind,
      label: again.label,
    );
  }

  void dismiss() => state = const VaultUploadState();

  @override
  VaultUploadState build() {
    ref.listen(vaultSessionProvider, (previous, next) {
      if (!next.isUnlocked) {
        _opened.clear();
        _last = null;
      }
    });

    return const VaultUploadState();
  }

  Future<bool> addFile({
    required Uint8List bytes,
    required String filename,
    required String kind,
    String? label,
  }) async {
    final session = ref.read(vaultSessionProvider);
    if (!session.isUnlocked) return false;

    _last = (bytes: bytes, filename: filename, kind: kind, label: label);

    state = VaultUploadState(
      isBusy: true,
      stage: UploadStage.encrypting,
      filename: filename,
      totalBytes: bytes.length,
    );

    final repository = ref.read(vaultRepositoryProvider);
    final transfer = ref.read(vaultTransferProvider);
    final crypto = ref.read(vaultCryptoProvider);

    final payload = await transfer.encrypt(
      plaintext: bytes,
      umk: session.umk!,
      metadata: {'filename': filename, 'size': bytes.length},
      kind: kind,
    );

    final labelHash =
        label == null || label.trim().isEmpty
        ? null
        : await crypto.labelHash(umk: session.umk!, label: label);

    final body = <String, dynamic>{
      'passcode_id': session.passcodeId,
      'kind': kind,
      'size_bytes': payload.ciphertext.length,
      'chunk_count': payload.chunkCount,
      'encrypted_metadata': base64Encode(payload.encryptedMetadata),
      'wrapped_dek': base64Encode(payload.wrappedDek),
      'salt_item': base64Encode(payload.saltItem),
      'visibility': labelHash == null ? 'normal' : 'hidden',
    };
    if (labelHash != null) body['label_hash'] = labelHash;

    final created = await repository.createItem(body);

    final result = created.valueOrNull;
    if (result == null) {
      state = VaultUploadState(
        error: created.failureOrNull!.message,
        stage: UploadStage.failed,
        filename: filename,
      );
      return false;
    }

    state = state.copyWith(
      stage: UploadStage.sending,
      totalBytes: payload.ciphertext.length,
    );

    try {
      await transfer.upload(
        url: result.uploadUrl,
        ciphertext: payload.ciphertext,
        onProgress: (progress) => state = state.copyWith(
          progress: progress.fraction,
          sentBytes: progress.sent,
          totalBytes: progress.total,
        ),
      );
    } catch (_) {
      state = state.copyWith(
        stage: UploadStage.failed,
        error: 'The upload did not finish. Check your connection and try again.',
      );
      return false;
    }

    state = state.copyWith(stage: UploadStage.finishing);

    final completed = await repository.completeItem(
      result.item.itemId,
      chunkCount: payload.chunkCount,
      totalSize: payload.ciphertext.length,
    );

    if (!completed.isSuccess) {
      state = state.copyWith(
        stage: UploadStage.failed,
        error: completed.failureOrNull!.message,
      );
      return false;
    }

    state = const VaultUploadState();
    ref.invalidate(vaultItemsProvider);
    ref.invalidate(vaultOverviewProvider);
    return true;
  }

  final _opened = <String, Uint8List>{};

  Uint8List? cached(String itemId) => _opened[itemId];

  void forget(String itemId) => _opened.remove(itemId);

  Future<Uint8List?> openItem(VaultItem item) async {
    final ready = _opened[item.itemId];
    if (ready != null) return ready;

    final session = ref.read(vaultSessionProvider);
    if (!session.isUnlocked || item.wrappedDek == null) return null;

    final repository = ref.read(vaultRepositoryProvider);
    final transfer = ref.read(vaultTransferProvider);

    final urlResult = await repository.downloadUrl(item.itemId);
    final url = urlResult.valueOrNull;
    if (url == null) return null;

    final ciphertext = await transfer.download(url: url);

    try {
      final metadata = await transfer.decryptMetadata(
        encryptedMetadata: Uint8List.fromList(base64Decode(item.encryptedMetadata)),
        wrappedDek: Uint8List.fromList(base64Decode(item.wrappedDek!)),
        saltItem: Uint8List.fromList(base64Decode(item.saltItem!)),
        umk: session.umk!,
      );

      final plain = await transfer.decrypt(
        ciphertext: ciphertext,
        wrappedDek: Uint8List.fromList(base64Decode(item.wrappedDek!)),
        saltItem: Uint8List.fromList(base64Decode(item.saltItem!)),
        umk: session.umk!,
        compression: metadata['compression'] as String? ?? 'none',
      );

      if (_opened.length > 4) _opened.remove(_opened.keys.first);
      _opened[item.itemId] = plain;
      return plain;
    } catch (_) {
      return null;
    }
  }
}
