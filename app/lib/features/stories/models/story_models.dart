class SharedStory {
  const SharedStory({
    required this.storyId,
    required this.excerpt,
    required this.author,
    this.title,
    this.slug,
  });

  factory SharedStory.fromJson(Map<String, dynamic> json) => SharedStory(
    storyId: json['story_id'] as String,
    excerpt: json['excerpt'] as String? ?? '',
    author: StoryAuthor.fromJson(
      Map<String, dynamic>.from(json['author'] as Map? ?? {}),
    ),
    title: json['title'] as String?,
    slug: json['slug'] as String?,
  );

  final String storyId;
  final String excerpt;
  final StoryAuthor author;
  final String? title;
  final String? slug;
}

class StoryAuthor {
  const StoryAuthor({
    required this.userId,
    required this.displayName,
    required this.avatarSeed,
    required this.username,
  });

  factory StoryAuthor.fromJson(Map<String, dynamic> json) => StoryAuthor(
    userId: json['user_id'] as String?,
    displayName: json['display_name'] as String? ?? 'A deleted account',
    avatarSeed: json['avatar_seed'] as String? ?? '',
    username: json['username'] as String?,
  );

  final String? userId;
  final String displayName;
  final String avatarSeed;
  final String? username;

  String get handle => username ?? displayName;

  bool get isReachable => username != null && username!.isNotEmpty;
}

const publishableVisibilities = {'public', 'private', 'scheduled'};

class Story {
  const Story({
    required this.storyId,
    required this.author,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.visibility,
    required this.slug,
    required this.likes,
    required this.comments,
    required this.readingMinutes,
    required this.isLiked,
    required this.publishedAt,
    this.scheduledFor,
    required this.createdAt,
    required this.updatedAt,
    this.editedAt,
    this.shared,
    this.likedBy = const [],
    this.images = const [],
    this.imageRatio,
    this.imageFit = 'cover',
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    return Story(
      storyId: json['story_id'] as String,
      author: StoryAuthor.fromJson(
        Map<String, dynamic>.from(json['author'] as Map? ?? {}),
      ),
      title: json['title'] as String?,
      excerpt: json['excerpt'] as String? ?? '',
      body: json['body'] as String?,
      visibility: json['visibility'] as String,
      slug: json['slug'] as String?,
      likes: counts['likes'] as int? ?? 0,
      comments: counts['comments'] as int? ?? 0,
      readingMinutes: json['reading_minutes'] as int? ?? 1,
      isLiked: json['is_liked'] as bool? ?? false,
      publishedAt: json['published_at'] as String?,
      scheduledFor: json['scheduled_for'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      editedAt: json['edited_at'] as String?,
      likedBy: (json['liked_by'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                StoryAuthor.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      imageRatio: (json['image_ratio'] as num?)?.toDouble(),
      imageFit: json['image_fit'] as String? ?? 'cover',
      shared: json['shared'] == null
          ? null
          : SharedStory.fromJson(
              Map<String, dynamic>.from(json['shared'] as Map),
            ),
    );
  }

  final String storyId;
  final StoryAuthor author;
  final String? title;
  final String excerpt;
  final String? body;
  final String visibility;
  final String? slug;
  final int likes;
  final int comments;
  final int readingMinutes;
  final bool isLiked;
  final String? publishedAt;
  final String? scheduledFor;
  final String createdAt;
  final String updatedAt;
  final String? editedAt;
  final SharedStory? shared;
  final List<StoryAuthor> likedBy;
  final List<String> images;
  final double? imageRatio;
  final String imageFit;

  bool get isDraft => visibility == 'draft';

  bool get wasEdited => editedAt != null && editedAt!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'story_id': storyId,
    'author': {
      'user_id': author.userId,
      'display_name': author.displayName,
      'avatar_seed': author.avatarSeed,
      'username': author.username,
    },
    'title': title,
    'excerpt': excerpt,
    'visibility': visibility,
    'slug': slug,
    'counts': {'likes': likes, 'comments': comments},
    'liked_by': [
      for (final person in likedBy)
        {
          'user_id': person.userId,
          'display_name': person.displayName,
          'avatar_seed': person.avatarSeed,
          'username': person.username,
        },
    ],
    'reading_minutes': readingMinutes,
    'is_liked': isLiked,
    'published_at': publishedAt,
    'scheduled_for': scheduledFor,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'edited_at': editedAt,
    'images': images,
    'image_ratio': imageRatio,
    'image_fit': imageFit,
    if (shared != null)
      'shared': {
        'story_id': shared!.storyId,
        'title': shared!.title,
        'excerpt': shared!.excerpt,
        'slug': shared!.slug,
        'author': {
          'user_id': shared!.author.userId,
          'display_name': shared!.author.displayName,
          'avatar_seed': shared!.author.avatarSeed,
          'username': shared!.author.username,
        },
      },
  };

  bool get isPublic => visibility == 'public';

  bool get isEditable => true;

  bool get isScheduled => visibility == 'scheduled';

  Story copyWith({
    int? likes,
    int? comments,
    bool? isLiked,
    String? visibility,
  }) => Story(
    shared: shared,
    likedBy: likedBy,
    images: images,
    imageRatio: imageRatio,
    imageFit: imageFit,
    storyId: storyId,
    author: author,
    title: title,
    excerpt: excerpt,
    body: body,
    visibility: visibility ?? this.visibility,
    slug: slug,
    likes: likes ?? this.likes,
    comments: comments ?? this.comments,
    readingMinutes: readingMinutes,
    isLiked: isLiked ?? this.isLiked,
    publishedAt: publishedAt,
    scheduledFor: scheduledFor,
    createdAt: createdAt,
    updatedAt: updatedAt,
    editedAt: editedAt,
  );
}

class StoryPage {
  const StoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory StoryPage.fromJson(Map<String, dynamic> json) => StoryPage(
    items: (json['items'] as List<dynamic>)
        .map((item) => Story.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
    hasMore: json['has_more'] as bool? ?? false,
  );

  final List<Story> items;
  final String? nextCursor;
  final bool hasMore;
}

class Liker {
  const Liker({
    required this.person,
    required this.isFollowing,
    required this.isMe,
    this.followsMe = false,
  });

  factory Liker.fromJson(Map<String, dynamic> json) => Liker(
    person: StoryAuthor.fromJson(json),
    isFollowing: json['is_following'] as bool? ?? false,
    followsMe: json['follows_me'] as bool? ?? false,
    isMe: json['is_me'] as bool? ?? false,
  );

  final StoryAuthor person;
  final bool isFollowing;
  final bool followsMe;
  final bool isMe;

  Liker copyWith({bool? isFollowing}) => Liker(
    person: person,
    isFollowing: isFollowing ?? this.isFollowing,
    followsMe: followsMe,
    isMe: isMe,
  );
}

class LikersPage {
  const LikersPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory LikersPage.fromJson(Map<String, dynamic> json) => LikersPage(
    items: (json['items'] as List<dynamic>)
        .map((item) => Liker.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
    hasMore: json['has_more'] as bool? ?? false,
  );

  final List<Liker> items;
  final String? nextCursor;
  final bool hasMore;
}

class Comment {
  const Comment({
    required this.commentId,
    required this.storyId,
    required this.parentId,
    required this.author,
    required this.body,
    required this.likes,
    required this.replyCount,
    required this.isLiked,
    required this.createdAt,
    this.canDelete = false,
    this.editedAt,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    return Comment(
      commentId: json['comment_id'] as String,
      storyId: json['story_id'] as String,
      parentId: json['parent_id'] as String?,
      author: StoryAuthor.fromJson(
        Map<String, dynamic>.from(json['author'] as Map? ?? {}),
      ),
      body: json['body'] as String,
      likes: counts['likes'] as int? ?? 0,
      replyCount: counts['replies'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      editedAt: json['edited_at'] as String?,
      replies: (json['replies'] as List<dynamic>? ?? [])
          .map(
            (item) => Comment.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  final String commentId;
  final String storyId;
  final String? parentId;
  final StoryAuthor author;
  final String? editedAt;
  final String body;
  final int likes;
  final int replyCount;
  final bool isLiked;
  final bool canDelete;
  final String createdAt;
  final List<Comment> replies;

  bool get hasMoreReplies => replyCount > replies.length;

  Comment copyWith({int? likes, bool? isLiked, List<Comment>? replies}) =>
      Comment(
        commentId: commentId,
        storyId: storyId,
        parentId: parentId,
        author: author,
        body: body,
        likes: likes ?? this.likes,
        replyCount: replyCount,
        isLiked: isLiked ?? this.isLiked,
        canDelete: canDelete,
        createdAt: createdAt,
        editedAt: editedAt,
        replies: replies ?? this.replies,
      );
}

class PublishOutcome {
  const PublishOutcome({
    required this.story,
    this.suggestedCommunity,
    this.needsCare = false,
  });

  factory PublishOutcome.fromJson(Map<String, dynamic> json) => PublishOutcome(
    story: Story.fromJson(Map<String, dynamic>.from(json['story'] as Map)),
    suggestedCommunity: json['suggested_community'] as String?,
    needsCare: json['needs_care'] as bool? ?? false,
  );

  final Story story;
  final String? suggestedCommunity;
  final bool needsCare;
}
