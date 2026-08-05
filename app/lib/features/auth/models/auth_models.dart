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
    required this.counts,
    required this.prefs,
    required this.emailMasked,
    required this.emailVerified,
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
    counts: Map<String, dynamic>.from(json['counts'] as Map? ?? {}),
    prefs: Map<String, dynamic>.from(json['prefs'] as Map? ?? {}),
    emailMasked: json['email_masked'] as String?,
    emailVerified: json['email_verified'] as bool? ?? false,
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
  final Map<String, dynamic> counts;
  final Map<String, dynamic> prefs;
  final String? emailMasked;
  final bool emailVerified;
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


class InterestOption {
  const InterestOption({
    required this.slug,
    required this.name,
    required this.categoryId,
  });

  factory InterestOption.fromJson(Map<String, dynamic> json) => InterestOption(
    slug: json['slug'] as String,
    name: json['name'] as String,
    categoryId: json['category_id'] as String,
  );

  final String slug;
  final String name;
  final String categoryId;
}

class SessionInfo {
  const SessionInfo({
    required this.familyId,
    required this.isCurrent,
    required this.label,
    required this.platform,
    required this.lastSeenAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
    familyId: json['family_id'] as String,
    isCurrent: json['is_current'] as bool? ?? false,
    label: json['label'] as String? ?? 'Unknown device',
    platform: json['platform'] as String? ?? 'web',
    lastSeenAt: json['last_seen_at'] as String?,
  );

  final String familyId;
  final bool isCurrent;
  final String label;
  final String platform;
  final String? lastSeenAt;
}
