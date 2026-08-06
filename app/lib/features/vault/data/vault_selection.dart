import '../models/vault_models.dart';

List<VaultPasscode> vaultsOnly(List<VaultPasscode> passcodes) =>
    passcodes.where((passcode) => passcode.scope == 'vault').toList();

VaultPasscode? selectVault(List<VaultPasscode> passcodes, String? passcodeId) {
  final vaults = vaultsOnly(passcodes);
  if (vaults.isEmpty) return null;
  if (passcodeId == null) return vaults.first;

  for (final vault in vaults) {
    if (vault.passcodeId == passcodeId) return vault;
  }
  return null;
}

bool canCreateVault({required bool hasKeys, required String password}) =>
    hasKeys || password.trim().isNotEmpty;
