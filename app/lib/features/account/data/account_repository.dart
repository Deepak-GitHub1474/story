import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';

class EmailState {
  const EmailState({
    required this.masked,
    required this.verified,
    this.expiresIn = const Duration(minutes: 10),
    this.resendAfter = const Duration(seconds: 30),
  });

  factory EmailState.fromJson(Map<String, dynamic> json) => EmailState(
    masked: json['email_masked'] as String?,
    verified: json['email_verified'] as bool? ?? false,
    expiresIn: Duration(seconds: json['expires_in'] as int? ?? 600),
    resendAfter: Duration(seconds: json['resend_after'] as int? ?? 30),
  );

  final String? masked;
  final bool verified;
  final Duration expiresIn;
  final Duration resendAfter;
}

class ResetAsk {
  const ResetAsk({required this.expiresIn, required this.resendAfter});

  factory ResetAsk.fromJson(Map<String, dynamic> json) => ResetAsk(
    expiresIn: Duration(seconds: json['expires_in'] as int? ?? 600),
    resendAfter: Duration(seconds: json['resend_after'] as int? ?? 30),
  );

  final Duration expiresIn;
  final Duration resendAfter;
}

class AccountRepository {
  const AccountRepository(this._client);

  final ApiClient _client;

  Future<Result<EmailState>> addEmail(String email) => _client.post(
    Endpoints.email,
    body: {'email': email},
    parse: EmailState.fromJson,
  );

  Future<Result<EmailState>> resendOtp() => _client.post(
    Endpoints.emailResend,
    body: const {},
    parse: EmailState.fromJson,
  );

  Future<Result<EmailState>> verifyEmail(String otp) => _client.post(
    Endpoints.emailVerify,
    body: {'otp': otp},
    parse: EmailState.fromJson,
  );

  Future<Result<bool>> removeEmail(String password) => _client.delete(
    Endpoints.email,
    body: {'password': password},
    parse: (data) => data['email_removed'] as bool? ?? true,
  );

  Future<Result<ResetAsk>> requestReset(String username) => _client.post(
    Endpoints.resetRequest,
    body: {'username': username},
    skipAuth: true,
    parse: ResetAsk.fromJson,
  );

  Future<Result<String>> verifyReset({
    required String username,
    required String otp,
  }) => _client.post(
    Endpoints.resetVerify,
    body: {'username': username, 'otp': otp},
    skipAuth: true,
    parse: (data) => data['reset_token'] as String,
  );

  Future<Result<bool>> completeReset({
    required String resetToken,
    required String newPassword,
  }) => _client.post(
    Endpoints.resetComplete,
    body: {
      'reset_token': resetToken,
      'new_password': newPassword,
      'acknowledged_vault_loss': true,
    },
    skipAuth: true,
    parse: (data) => data['password_reset'] as bool? ?? true,
  );

  Future<Result<bool>> deactivate(String password) => _client.post(
    Endpoints.deactivate,
    body: {'password': password},
    parse: (data) => true,
  );

  Future<Result<String>> requestDeletion(String password) => _client.post(
    Endpoints.deleteAccount,
    body: {'password': password, 'acknowledged': true},
    parse: (data) => data['deletes_at'] as String,
  );

  Future<Result<bool>> cancelDeletion({
    required String username,
    required String password,
  }) => _client.post(
    Endpoints.cancelDeletion,
    body: {'username': username, 'password': password},
    skipAuth: true,
    parse: (data) => true,
  );
}
