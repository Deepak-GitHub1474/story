class Community {
  const Community({
    required this.slug,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.members,
    required this.stories,
    required this.isMember,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    return Community(
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      members: counts['members'] as int? ?? 0,
      stories: counts['stories'] as int? ?? 0,
      isMember: json['is_member'] as bool? ?? false,
    );
  }

  final String slug;
  final String name;
  final String description;
  final String categoryId;
  final int members;
  final int stories;
  final bool isMember;

  Community copyWith({bool? isMember, int? members}) => Community(
    slug: slug,
    name: name,
    description: description,
    categoryId: categoryId,
    members: members ?? this.members,
    stories: stories,
    isMember: isMember ?? this.isMember,
  );
}

class Category {
  const Category({
    required this.slug,
    required this.name,
    required this.tone,
    required this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    slug: json['slug'] as String,
    name: json['name'] as String,
    tone: json['tone'] as String? ?? 'reflective',
    description: json['description'] as String? ?? '',
  );

  final String slug;
  final String name;
  final String tone;
  final String description;
}

class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarSeed,
    required this.bio,
    required this.interests,
    required this.stories,
    required this.followers,
    required this.following,
    required this.isFollowing,
    required this.isMe,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    return PublicProfile(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarSeed: json['avatar_seed'] as String? ?? '',
      bio: json['bio'] as String?,
      interests: (json['interests'] as List<dynamic>? ?? []).cast<String>(),
      stories: counts['stories'] as int? ?? 0,
      followers: counts['followers'] as int? ?? 0,
      following: counts['connections'] as int? ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
      isMe: json['is_me'] as bool? ?? false,
    );
  }

  final String userId;
  final String username;
  final String displayName;
  final String avatarSeed;
  final String? bio;
  final List<String> interests;
  final int stories;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool isMe;

  PublicProfile copyWith({bool? isFollowing, int? followers}) => PublicProfile(
    userId: userId,
    username: username,
    displayName: displayName,
    avatarSeed: avatarSeed,
    bio: bio,
    interests: interests,
    stories: stories,
    followers: followers ?? this.followers,
    following: following,
    isFollowing: isFollowing ?? this.isFollowing,
    isMe: isMe,
  );
}

class SuggestedPerson {
  const SuggestedPerson({
    required this.userId,
    required this.displayName,
    required this.reason,
    this.username,
    this.avatarSeed = '',
  });

  factory SuggestedPerson.fromJson(Map<String, dynamic> json) => SuggestedPerson(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String? ?? 'Someone',
    reason: json['reason'] as String? ?? '',
    username: json['username'] as String?,
    avatarSeed: json['avatar_seed'] as String? ?? '',
  );

  final String userId;
  final String displayName;
  final String reason;
  final String? username;
  final String avatarSeed;
}

class Suggestions {
  const Suggestions({required this.communities, required this.people});

  factory Suggestions.fromJson(Map<String, dynamic> json) => Suggestions(
    communities: (json['communities'] as List<dynamic>? ?? [])
        .map((item) => Community.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    people: (json['people'] as List<dynamic>? ?? [])
        .map((item) => SuggestedPerson.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  final List<Community> communities;
  final List<SuggestedPerson> people;

  bool get isEmpty => communities.isEmpty && people.isEmpty;
}
