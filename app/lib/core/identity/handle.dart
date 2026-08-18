bool namesDiffer({required String displayName, required String username}) {
  final handle = username.trim();
  if (handle.isEmpty) return false;
  return displayName.trim().toLowerCase() != handle.toLowerCase();
}

String? handleFor({required String displayName, required String username}) =>
    namesDiffer(displayName: displayName, username: username)
    ? '@${username.trim()}'
    : null;
