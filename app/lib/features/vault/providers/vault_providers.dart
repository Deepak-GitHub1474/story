import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/vault_crypto.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/vault_repository.dart';
import '../models/vault_models.dart';

final vaultRepositoryProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(ref.watch(apiClientProvider)),
);

final vaultCryptoProvider = Provider<VaultCrypto>((ref) => const VaultCrypto());

final vaultOverviewProvider = FutureProvider<VaultOverview?>((ref) async {
  final result = await ref.watch(vaultRepositoryProvider).overview();
  return result.valueOrNull;
});

enum VaultLockState { locked, unlocked, needsSetup }

class VaultSession {
  const VaultSession({
    required this.state,
    this.umk,
    this.passcodeKey,
    this.passcodeId,
    this.error,
  });

  final VaultLockState state;
  final Uint8List? umk;
  final Uint8List? passcodeKey;
  final String? passcodeId;
  final String? error;

  bool get isUnlocked => state == VaultLockState.unlocked && umk != null;
}

final vaultSessionProvider = NotifierProvider<VaultSessionNotifier, VaultSession>(
  VaultSessionNotifier.new,
);

class VaultSessionNotifier extends Notifier<VaultSession> {
  @override
  VaultSession build() => const VaultSession(state: VaultLockState.locked);

  VaultCrypto get _crypto => ref.read(vaultCryptoProvider);

  VaultRepository get _repository => ref.read(vaultRepositoryProvider);

  Future<bool> setUpKeys(String password) async {
    final crypto = _crypto;
    final userId = ref.read(authProvider).user?.userId ?? '';

    final salt = await crypto.randomBytes(VaultCrypto.saltLength);
    final umk = await crypto.randomBytes(VaultCrypto.keyLength);
    const kdf = KdfParams();

    final kek = await crypto.deriveKek(
      Uint8List.fromList(utf8.encode(password)),
      salt,
      kdf,
    );
    final wrapped = await crypto.wrap(
      key: kek,
      plaintext: umk,
      aad: '${VaultCrypto.umkAadPrefix}$userId',
    );

    final result = await _repository.initKeys(
      saltPw: base64Encode(salt),
      wrappedUmk: base64Encode(wrapped),
      kdf: kdf.toJson(),
    );

    if (!result.isSuccess) {
      state = VaultSession(state: state.state, error: result.failureOrNull!.message);
      return false;
    }

    state = VaultSession(state: VaultLockState.locked, umk: null);
    return true;
  }

  Future<bool> unlock({required String password, required String passcode}) async {
    final crypto = _crypto;
    final userId = ref.read(authProvider).user?.userId ?? '';

    final keysResult = await _repository.keys();
    final keys = keysResult.valueOrNull;
    if (keys == null) {
      state = const VaultSession(state: VaultLockState.needsSetup);
      return false;
    }

    final kdf = KdfParams.fromJson(keys.kdf);
    final kek = await crypto.deriveKek(
      Uint8List.fromList(utf8.encode(password)),
      Uint8List.fromList(base64Decode(keys.saltPw)),
      kdf,
    );

    Uint8List umk;
    try {
      umk = await crypto.unwrap(
        key: kek,
        sealed: Uint8List.fromList(base64Decode(keys.wrappedUmk)),
        aad: '${VaultCrypto.umkAadPrefix}$userId',
      );
    } catch (_) {
      state = const VaultSession(
        state: VaultLockState.locked,
        error: 'That password did not unlock your vault.',
      );
      return false;
    }

    final overview = await _repository.overview();
    final passcodes = overview.valueOrNull?.passcodes ?? const [];
    if (passcodes.isEmpty) {
      state = VaultSession(state: VaultLockState.needsSetup, umk: umk);
      return false;
    }

    final passcodeKey = await crypto.deriveKek(
      Uint8List.fromList(utf8.encode(passcode)),
      await crypto.randomBytes(VaultCrypto.saltLength),
      kdf,
    );

    state = VaultSession(
      state: VaultLockState.unlocked,
      umk: umk,
      passcodeKey: passcodeKey,
      passcodeId: passcodes.first.passcodeId,
    );
    return true;
  }

  void lock() {
    state = const VaultSession(state: VaultLockState.locked);
  }

  Future<String?> hashLabel(String label) async {
    final umk = state.umk;
    if (umk == null) return null;
    return _crypto.labelHash(umk: umk, label: label);
  }
}

final vaultItemsProvider = FutureProvider<List<VaultItem>>((ref) async {
  if (!ref.watch(vaultSessionProvider).isUnlocked) return const [];
  final result = await ref.watch(vaultRepositoryProvider).items();
  return result.valueOrNull ?? const [];
});
