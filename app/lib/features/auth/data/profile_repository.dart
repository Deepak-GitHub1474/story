import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/auth_models.dart';

Map<String, dynamic> _profilePatch({
  String? displayName,
  String? bio,
  List<String>? interests,
  Map<String, dynamic>? prefs,
}) {
  final patch = <String, dynamic>{};
  if (displayName != null) patch['display_name'] = displayName;
  if (bio != null) patch['bio'] = bio;
  if (interests != null) patch['interests'] = interests;
  if (prefs != null) patch['prefs'] = prefs;
  return patch;
}

class ProfileRepository {
  const ProfileRepository(this._client);

  final ApiClient _client;

  Future<Result<List<InterestOption>>> interests() => _client.get(
    Endpoints.interests,
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => InterestOption.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<AppUser>> updateProfile({
    String? displayName,
    String? bio,
    List<String>? interests,
    Map<String, dynamic>? prefs,
  }) => _client.patch(
    Endpoints.updateProfile,
    body: _profilePatch(
      displayName: displayName,
      bio: bio,
      interests: interests,
      prefs: prefs,
    ),
    parse: (data) => AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
  );

  Future<Result<AppUser>> regenerateAvatar() => _client.post(
    Endpoints.regenerateAvatar,
    parse: (data) => AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
  );

  Future<Result<List<SessionInfo>>> sessions() => _client.get(
    Endpoints.sessions,
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => SessionInfo.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<bool>> revokeSession(String familyId) => _client.delete(
    '${Endpoints.sessions}/$familyId',
    parse: (data) => data['revoked'] as bool? ?? true,
  );

  Future<Result<bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _client.post(
    Endpoints.changePassword,
    body: {'current_password': currentPassword, 'new_password': newPassword},
    parse: (data) => data['password_changed'] as bool? ?? true,
  );
}
