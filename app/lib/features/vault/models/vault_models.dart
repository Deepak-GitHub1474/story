class VaultKeys {
  const VaultKeys({
    required this.saltPw,
    required this.wrappedUmk,
    required this.kdf,
    required this.umkVersion,
  });

  factory VaultKeys.fromJson(Map<String, dynamic> json) => VaultKeys(
    saltPw: json['salt_pw'] as String,
    wrappedUmk: json['wrapped_umk'] as String,
    kdf: Map<String, dynamic>.from(json['kdf'] as Map? ?? {}),
    umkVersion: json['umk_version'] as int? ?? 1,
  );

  final String saltPw;
  final String wrappedUmk;
  final Map<String, dynamic> kdf;
  final int umkVersion;
}

class VaultPasscode {
  const VaultPasscode({
    required this.passcodeId,
    required this.label,
    required this.scope,
    required this.saltPc,
    required this.kdf,
    required this.keySource,
    this.wrappedUmk,
  });

  factory VaultPasscode.fromJson(Map<String, dynamic> json) => VaultPasscode(
    passcodeId: json['passcode_id'] as String,
    label: json['label'] as String,
    scope: json['scope'] as String? ?? 'vault',
    saltPc: json['salt_pc'] as String? ?? '',
    kdf: Map<String, dynamic>.from(json['kdf'] as Map? ?? {}),
    keySource: json['key_source'] as String? ?? 'master',
    wrappedUmk: json['wrapped_umk'] as String?,
  );

  final String passcodeId;
  final String label;
  final String scope;
  final String saltPc;
  final Map<String, dynamic> kdf;
  final String keySource;
  final String? wrappedUmk;

  bool get hasOwnKey => keySource == 'own' && wrappedUmk != null;
}

class VaultItem {
  const VaultItem({
    required this.itemId,
    required this.kind,
    required this.sizeBytes,
    required this.chunkCount,
    required this.encryptedMetadata,
    required this.visibility,
    required this.status,
    required this.keyState,
    required this.createdAt,
    this.wrappedDek,
    this.saltItem,
    this.thumbEncrypted,
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    itemId: json['item_id'] as String,
    kind: json['kind'] as String,
    sizeBytes: json['size_bytes'] as int,
    chunkCount: json['chunk_count'] as int,
    encryptedMetadata: json['encrypted_metadata'] as String,
    visibility: json['visibility'] as String,
    status: json['status'] as String,
    keyState: json['key_state'] as String? ?? 'active',
    createdAt: json['created_at'] as String? ?? '',
    wrappedDek: json['wrapped_dek'] as String?,
    saltItem: json['salt_item'] as String?,
    thumbEncrypted: json['thumb_encrypted'] as String?,
  );

  final String itemId;
  final String kind;
  final int sizeBytes;
  final int chunkCount;
  final String encryptedMetadata;
  final String visibility;
  final String status;
  final String keyState;
  final String createdAt;
  final String? wrappedDek;
  final String? saltItem;
  final String? thumbEncrypted;

  bool get isHidden => visibility == 'hidden';

  bool get isReady => status == 'ready';

  bool get isOrphaned => keyState == 'orphaned';
}

class VaultOverview {
  const VaultOverview({
    required this.itemCount,
    required this.usedBytes,
    required this.limitBytes,
    required this.orphanedCount,
    required this.passcodes,
  });

  factory VaultOverview.fromJson(Map<String, dynamic> json) => VaultOverview(
    itemCount: json['item_count'] as int? ?? 0,
    usedBytes: json['used_bytes'] as int? ?? 0,
    limitBytes: json['limit_bytes'] as int? ?? 0,
    orphanedCount: json['orphaned_count'] as int? ?? 0,
    passcodes: (json['passcodes'] as List<dynamic>? ?? [])
        .map((item) => VaultPasscode.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  final int itemCount;
  final int usedBytes;
  final int limitBytes;
  final int orphanedCount;
  final List<VaultPasscode> passcodes;

  bool get hasPasscode => passcodes.isNotEmpty;
}
