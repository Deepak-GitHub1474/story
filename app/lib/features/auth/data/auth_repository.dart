import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/auth_models.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  Future<Result<bool>> isUsernameAvailable(String username) => _client.post(
    Endpoints.usernameAvailable,
    body: {'username': username},
    skipAuth: true,
    parse: (data) => data['available'] as bool,
  );

  Future<Result<AuthSession>> signup({
    required String username,
    required String password,
    required bool tncAccepted,
    String? referralCode,
  }) => _client.post(
    Endpoints.signup,
    body: {
      'username': username,
      'password': password,
      'tnc_accepted': tncAccepted,
      if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
    },
    skipAuth: true,
    parse: AuthSession.fromJson,
  );

  Future<Result<AuthSession>> signin({
    required String username,
    required String password,
  }) => _client.post(
    Endpoints.signin,
    body: {
      'username': username,
      'password': password,
      'device': _currentDevice().toJson(),
    },
    skipAuth: true,
    parse: AuthSession.fromJson,
  );

  Future<Result<AppUser>> me() => _client.get(
    Endpoints.me,
    parse: (data) => AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
  );

  Future<Result<bool>> signout() => _client.post(
    Endpoints.signout,
    parse: (data) => data['signed_out'] as bool? ?? true,
  );

  Future<Result<bool>> signoutEverywhere() => _client.post(
    Endpoints.signoutAll,
    parse: (data) => data['signed_out'] as bool? ?? true,
  );

  DeviceDetails _currentDevice() {
    if (Platform.isAndroid) {
      return const DeviceDetails(platform: 'android', appVersion: '0.1.0');
    }
    if (Platform.isIOS) {
      return const DeviceDetails(platform: 'ios', appVersion: '0.1.0');
    }
    return const DeviceDetails(platform: 'web', appVersion: '0.1.0');
  }
}
