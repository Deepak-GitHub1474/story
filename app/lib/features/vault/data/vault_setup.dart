const minimumPasscodeLength = 8;

enum VaultSetupError { sameAsPassword, tooShort }

VaultSetupError? validatePasscode({
  required String passcode,
  required String password,
}) {
  final trimmed = passcode.trim();
  if (trimmed.length < minimumPasscodeLength) return VaultSetupError.tooShort;
  if (trimmed.toLowerCase() == password.trim().toLowerCase()) {
    return VaultSetupError.sameAsPassword;
  }
  return null;
}

String messageFor(VaultSetupError error) => switch (error) {
  VaultSetupError.sameAsPassword =>
    'Your vault passcode must be different from your account password. '
        'Two secrets guard the vault, and reusing one leaves only one.',
  VaultSetupError.tooShort =>
    'Use at least $minimumPasscodeLength characters.',
};
