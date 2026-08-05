import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/vault_models.dart';

class VaultRepository {
  const VaultRepository(this._client);

  final ApiClient _client;

  Future<Result<bool>> initKeys({
    required String saltPw,
    required String wrappedUmk,
    required Map<String, dynamic> kdf,
  }) => _client.post(
    Endpoints.keys,
    body: {'salt_pw': saltPw, 'wrapped_umk': wrappedUmk, 'kdf': kdf},
    parse: (data) => data['keys_initialized'] as bool? ?? true,
  );

  Future<Result<VaultKeys>> keys() =>
      _client.get(Endpoints.keys, parse: VaultKeys.fromJson);

  Future<Result<VaultOverview>> overview() =>
      _client.get(Endpoints.vaultOverview, parse: VaultOverview.fromJson);

  Future<Result<VaultPasscode>> createPasscode({
    required String label,
    required String passcodeHash,
    required String saltPc,
    required Map<String, dynamic> kdf,
    required String escrowPayload,
  }) => _client.post(
    Endpoints.vaultPasscodes,
    body: {
      'label': label,
      'scope': 'vault',
      'passcode_hash': passcodeHash,
      'salt_pc': saltPc,
      'kdf': kdf,
      'escrow_payload': escrowPayload,
    },
    parse: (data) =>
        VaultPasscode.fromJson(Map<String, dynamic>.from(data['passcode'] as Map)),
  );

  Future<Result<List<VaultItem>>> items() => _client.get(
    Endpoints.vaultItems,
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => VaultItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<VaultItem>> item(String itemId) => _client.get(
    Endpoints.vaultItem(itemId),
    parse: (data) => VaultItem.fromJson(Map<String, dynamic>.from(data['item'] as Map)),
  );

  Future<Result<VaultItem>> findByLabel(String labelHash) => _client.post(
    Endpoints.vaultSearch,
    body: {'label_hash': labelHash},
    parse: (data) => VaultItem.fromJson(Map<String, dynamic>.from(data['item'] as Map)),
  );

  Future<Result<({VaultItem item, String uploadUrl})>> createItem(
    Map<String, dynamic> body,
  ) => _client.post(
    Endpoints.vaultItems,
    body: body,
    parse: (data) => (
      item: VaultItem.fromJson(Map<String, dynamic>.from(data['item'] as Map)),
      uploadUrl: data['upload_url'] as String,
    ),
  );

  Future<Result<VaultItem>> completeItem(
    String itemId, {
    required int chunkCount,
    required int totalSize,
  }) => _client.post(
    Endpoints.vaultItemComplete(itemId),
    body: {'chunk_count': chunkCount, 'total_size': totalSize},
    parse: (data) => VaultItem.fromJson(Map<String, dynamic>.from(data['item'] as Map)),
  );

  Future<Result<String>> downloadUrl(String itemId) => _client.get(
    Endpoints.vaultItemDownload(itemId),
    parse: (data) => data['download_url'] as String,
  );

  Future<Result<bool>> deleteItem(String itemId) => _client.delete(
    Endpoints.vaultItem(itemId),
    parse: (data) => data['deleted'] as bool? ?? true,
  );
}
