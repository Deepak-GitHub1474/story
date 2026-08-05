import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class KeychainStore implements KeyValueStore {
  const KeychainStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class SecureStore {
  const SecureStore([this._store = const KeychainStore()]);

  final KeyValueStore _store;

  static const _accessTokenKey = 'story.access_token';
  static const _refreshTokenKey = 'story.refresh_token';

  Future<String?> readAccessToken() => _store.read(_accessTokenKey);

  Future<String?> readRefreshToken() => _store.read(_refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _store.write(_accessTokenKey, accessToken);
    await _store.write(_refreshTokenKey, refreshToken);
  }

  Future<void> clear() async {
    await _store.delete(_accessTokenKey);
    await _store.delete(_refreshTokenKey);
  }
}
