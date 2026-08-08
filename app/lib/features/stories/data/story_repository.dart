import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/story_models.dart';

Map<String, dynamic> _patch({
  String? title,
  String? body,
  List<String>? images,
  double? imageRatio,
  String? imageFit,
}) {
  final patch = <String, dynamic>{};
  if (title != null) patch['title'] = title;
  if (body != null) patch['body'] = body;
  if (images != null) patch['images'] = images;
  if (imageRatio != null) patch['image_ratio'] = imageRatio;
  if (imageFit != null) patch['image_fit'] = imageFit;
  return patch;
}

Map<String, dynamic> _pageQuery({String? cursor, String? visibility, int limit = 20}) {
  final query = <String, dynamic>{'limit': limit};
  if (cursor != null) query['cursor'] = cursor;
  if (visibility != null) query['visibility'] = visibility;
  return query;
}

Map<String, dynamic> _commentBody(String body, String? parentId) {
  final payload = <String, dynamic>{'body': body};
  if (parentId != null) payload['parent_id'] = parentId;
  return payload;
}

Map<String, dynamic> _publishBody(
  String visibility,
  String? communitySlug,
  DateTime? scheduledFor,
  bool exposureAck,
) {
  final payload = <String, dynamic>{'visibility': visibility};
  if (exposureAck) payload['exposure_ack'] = true;
  if (communitySlug != null) payload['community_slug'] = communitySlug;
  if (scheduledFor != null) {
    payload['scheduled_for'] = scheduledFor.toUtc().toIso8601String();
  }
  return payload;
}

class StoryRepository {
  const StoryRepository(this._client);

  final ApiClient _client;

  Future<Result<String>> uploadImage({
    required String kind,
    required String base64Data,
  }) => _client.post(
    Endpoints.mediaImages,
    body: {'kind': kind, 'data': base64Data},
    parse: (data) => data['url'] as String,
  );

  Future<Result<String>> polish({
    required String text,
    required String instruction,
  }) => _client.post(
    Endpoints.aiPolish,
    body: {'text': text, 'instruction': instruction},
    parse: (data) => data['text'] as String,
  );

  Future<Result<Story>> create({
    String? title,
    required String body,
    String? sharedStoryId,
    List<String> images = const [],
    double? imageRatio,
    String imageFit = 'cover',
  }) => _client.post(
    Endpoints.stories,
    body: {
      'title': title,
      'body': body,
      'shared_story_id': ?sharedStoryId,
      if (images.isNotEmpty) ...{
        'images': images,
        'image_ratio': ?imageRatio,
        'image_fit': imageFit,
      },
    },
    parse: (data) => Story.fromJson(Map<String, dynamic>.from(data['story'] as Map)),
  );

  Future<Result<Story>> update(
    String storyId, {
    String? title,
    String? body,
    List<String>? images,
    double? imageRatio,
    String? imageFit,
  }) => _client.patch(
    Endpoints.story(storyId),
    body: _patch(
      title: title,
      body: body,
      images: images,
      imageRatio: imageRatio,
      imageFit: imageFit,
    ),
    parse: (data) => Story.fromJson(Map<String, dynamic>.from(data['story'] as Map)),
  );

  Future<Result<PublishOutcome>> publish(
    String storyId, {
    required String visibility,
    String? communitySlug,
    DateTime? scheduledFor,
    bool exposureAck = false,
  }) => _client.post(
    Endpoints.publishStory(storyId),
    body: _publishBody(visibility, communitySlug, scheduledFor, exposureAck),
    parse: PublishOutcome.fromJson,
  );

  Future<Result<Story>> unpublish(String storyId) => _client.post(
    Endpoints.unpublishStory(storyId),
    parse: (data) => Story.fromJson(Map<String, dynamic>.from(data['story'] as Map)),
  );

  Future<Result<bool>> remove(String storyId) => _client.delete(
    Endpoints.story(storyId),
    parse: (data) => data['deleted'] as bool? ?? true,
  );

  Future<Result<Story>> byId(String storyId) => _client.get(
    Endpoints.story(storyId),
    parse: (data) => Story.fromJson(Map<String, dynamic>.from(data['story'] as Map)),
  );

  Future<Result<StoryPage>> feed({String? cursor}) => _client.get(
    Endpoints.feed,
    query: _pageQuery(cursor: cursor),
    parse: StoryPage.fromJson,
  );

  Future<Result<StoryPage>> mine({String? visibility, String? cursor}) => _client.get(
    Endpoints.myStories,
    query: _pageQuery(cursor: cursor, visibility: visibility),
    parse: StoryPage.fromJson,
  );

  Future<Result<StoryPage>> byUser(String username, {String? cursor}) => _client.get(
    Endpoints.userStories(username),
    query: _pageQuery(cursor: cursor),
    parse: StoryPage.fromJson,
  );

  static int _likes(Map<String, dynamic> data) => data['likes'] as int;

  Future<Result<int>> setLike(String storyId, {required bool liked}) {
    final path = Endpoints.storyLike(storyId);
    return liked
        ? _client.post(path, parse: _likes)
        : _client.delete(path, parse: _likes);
  }

  Future<Result<List<Comment>>> comments(String storyId, {String? cursor}) => _client.get(
    Endpoints.storyComments(storyId),
    query: _pageQuery(cursor: cursor, limit: 50),
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => Comment.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<Comment>> editComment(String commentId, String body) => _client.patch(
    Endpoints.comment(commentId),
    body: {'body': body},
    parse: (data) => Comment.fromJson(Map<String, dynamic>.from(data['comment'] as Map)),
  );

  Future<Result<Comment>> addComment(
    String storyId,
    String body, {
    String? parentId,
  }) => _client.post(
    Endpoints.storyComments(storyId),
    body: _commentBody(body, parentId),
    parse: (data) => Comment.fromJson(Map<String, dynamic>.from(data['comment'] as Map)),
  );

  Future<Result<List<Comment>>> replies(String commentId) => _client.get(
    Endpoints.commentReplies(commentId),
    query: _pageQuery(limit: 50),
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => Comment.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<int>> setCommentLike(String commentId, {required bool liked}) {
    final path = Endpoints.commentLike(commentId);
    return liked
        ? _client.post(path, parse: _likes)
        : _client.delete(path, parse: _likes);
  }

  Future<Result<String>> share(String storyId) => _client.post(
    Endpoints.storyShare(storyId),
    parse: (data) => data['url'] as String,
  );

  Future<Result<bool>> deleteComment(String commentId) => _client.delete(
    Endpoints.comment(commentId),
    parse: (data) => data['deleted'] as bool? ?? true,
  );
}
