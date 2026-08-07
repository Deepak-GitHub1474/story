import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../../stories/models/story_models.dart';
import '../models/community_models.dart';

List<T> _mapItems<T>(Map<String, dynamic> data, T Function(Map<String, dynamic>) parse) =>
    (data['items'] as List<dynamic>)
        .map((item) => parse(Map<String, dynamic>.from(item as Map)))
        .toList();

class CommunityRepository {
  const CommunityRepository(this._client);

  final ApiClient _client;

  Future<Result<Suggestions>> suggestions() => _client.get(
    Endpoints.suggestions,
    parse: Suggestions.fromJson,
  );

  Future<Result<List<Category>>> categories() => _client.get(
    Endpoints.categories,
    parse: (data) => _mapItems(data, Category.fromJson),
  );

  Future<Result<List<Community>>> browse({String? category, String? query}) => _client.get(
    Endpoints.communities,
    query: _browseQuery(category, query),
    parse: (data) => _mapItems(data, Community.fromJson),
  );

  Future<Result<List<Community>>> mine() => _client.get(
    Endpoints.myCommunities,
    parse: (data) => _mapItems(data, Community.fromJson),
  );

  Future<Result<Community>> detail(String slug) => _client.get(
    Endpoints.community(slug),
    parse: (data) =>
        Community.fromJson(Map<String, dynamic>.from(data['community'] as Map)),
  );

  Future<Result<Community>> setMembership(String slug, {required bool join}) {
    final path = Endpoints.communityJoin(slug);
    Community parse(Map<String, dynamic> data) =>
        Community.fromJson(Map<String, dynamic>.from(data['community'] as Map));
    return join
        ? _client.post(path, parse: parse)
        : _client.delete(path, parse: parse);
  }

  Future<Result<StoryPage>> stories(String slug, {String? cursor}) => _client.get(
    Endpoints.communityStories(slug),
    query: _cursorQuery(cursor),
    parse: StoryPage.fromJson,
  );

  Future<Result<PublicProfile>> profile(String username) => _client.get(
    Endpoints.publicProfile(username),
    parse: (data) =>
        PublicProfile.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
  );

  Future<Result<bool>> setFollow(String username, {required bool follow}) {
    final path = Endpoints.connection(username);
    bool parse(Map<String, dynamic> data) => data['is_following'] as bool? ?? follow;
    return follow
        ? _client.post(path, parse: parse)
        : _client.delete(path, parse: parse);
  }

  Map<String, dynamic> _browseQuery(String? category, String? query) {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    if (query != null && query.isNotEmpty) params['q'] = query;
    return params;
  }

  Map<String, dynamic> _cursorQuery(String? cursor) {
    final params = <String, dynamic>{'limit': 20};
    if (cursor != null) params['cursor'] = cursor;
    return params;
  }
}
