class AppUser {
  const AppUser({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarSeed,
    required this.role,
    required this.status,
    required this.blocked,
    required this.referralCode,
    required this.referredBy,
    required this.bio,
    required this.interests,
    required this.onboarding,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    userId: json['user_id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    avatarSeed: json['avatar_seed'] as String,
    role: json['role'] as String,
    status: json['status'] as String,
    blocked: json['blocked'] as bool? ?? false,
    referralCode: json['referral_code'] as String? ?? '',
    referredBy: json['referred_by'] as String?,
    bio: json['bio'] as String?,
    interests: (json['interests'] as List<dynamic>? ?? []).cast<String>(),
    onboarding: Map<String, dynamic>.from(json['onboarding'] as Map? ?? {}),
    createdAt: json['created_at'] as String? ?? '',
  );

  final String userId;
  final String username;
  final String displayName;
  final String avatarSeed;
  final String role;
  final String status;
  final bool blocked;
  final String referralCode;
  final String? referredBy;
  final String? bio;
  final List<String> interests;
  final Map<String, dynamic> onboarding;
  final String createdAt;

  bool get interestsDone => onboarding['interests_done'] == true;
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );

  final String accessToken;
  final String refreshToken;
}

class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    tokens: AuthTokens.fromJson(Map<String, dynamic>.from(json['tokens'] as Map)),
  );

  final AppUser user;
  final AuthTokens tokens;
}

class DeviceDetails {
  const DeviceDetails({
    required this.platform,
    this.osVersion,
    this.appVersion,
    this.deviceModel,
  });

  final String platform;
  final String? osVersion;
  final String? appVersion;
  final String? deviceModel;

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'os_version': osVersion,
    'app_version': appVersion,
    'device_model': deviceModel,
  };
}
