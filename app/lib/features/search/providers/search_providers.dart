import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../communities/models/community_models.dart';
import '../../stories/models/story_models.dart';

class SearchResults {
  const SearchResults({
    this.users = const [],
    this.communities = const [],
    this.stories = const [],
  });

  final List<PublicProfile> users;
  final List<Community> communities;
  final List<Story> stories;

  bool get isEmpty => users.isEmpty && communities.isEmpty && stories.isEmpty;
}

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const SearchResults(),
    this.isLoading = false,
  });

  final String query;
  final SearchResults results;
  final bool isLoading;
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;
  int _generation = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void query(String value) {
    final trimmed = value.trim();
    state = SearchState(query: trimmed, results: state.results, isLoading: trimmed.isNotEmpty);

    _debounce?.cancel();
    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 320), () => _run(trimmed));
  }

  Future<void> _run(String value) async {
    final generation = ++_generation;
    final result = await ref.read(apiClientProvider).get<SearchResults>(
      '/search',
      query: {'q': value},
      parse: (data) => SearchResults(
        users: (data['users'] as List<dynamic>)
            .map((item) => PublicProfile.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        communities: (data['communities'] as List<dynamic>)
            .map((item) => Community.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        stories: (data['stories'] as List<dynamic>)
            .map((item) => Story.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      ),
    );

    if (generation != _generation) return;

    state = SearchState(
      query: value,
      results: result.valueOrNull ?? const SearchResults(),
      isLoading: false,
    );
  }
}
