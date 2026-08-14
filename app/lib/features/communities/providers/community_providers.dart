import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../people/screens/people_list_screen.dart';
import '../data/community_repository.dart';
import '../models/community_models.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(apiClientProvider)),
);

final suggestionsProvider = FutureProvider<Suggestions>((ref) async {
  final result = await ref.watch(communityRepositoryProvider).suggestions();
  return result.valueOrNull ?? const Suggestions(communities: [], people: []);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final result = await ref.watch(communityRepositoryProvider).categories();
  return result.valueOrNull ?? const [];
});

final myCommunitiesProvider = FutureProvider<List<Community>>((ref) async {
  final result = await ref.watch(communityRepositoryProvider).mine();
  return result.valueOrNull ?? const [];
});

final communityDetailProvider = FutureProvider.family<Community, String>((
  ref,
  slug,
) async {
  final result = await ref.watch(communityRepositoryProvider).detail(slug);
  final community = result.valueOrNull;
  if (community == null) throw Exception('Not found');
  return community;
});

final communityBrowseProvider =
    NotifierProvider<CommunityBrowseNotifier, AsyncValue<List<Community>>>(
      CommunityBrowseNotifier.new,
    );

class CommunityBrowseNotifier extends Notifier<AsyncValue<List<Community>>> {
  String? _category;

  @override
  AsyncValue<List<Community>> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  String? get category => _category;

  Future<void> load() async {
    final result = await ref
        .read(communityRepositoryProvider)
        .browse(category: _category);
    state = result.fold(
      onSuccess: (success) => AsyncValue.data(success.value),
      onFailure: (failure) =>
          AsyncValue.error(failure.message, StackTrace.current),
    );
  }

  Future<void> filter(String? category) async {
    _category = category;
    state = const AsyncValue.loading();
    await load();
  }

  Future<void> toggleMembership(Community community) async {
    final joining = !community.isMember;
    final before = state;
    final listed = state.valueOrNull;

    if (listed != null) {
      state = AsyncValue.data([
        for (final item in listed)
          if (item.slug == community.slug)
            item.copyWith(
              isMember: joining,
              members: item.members + (joining ? 1 : -1),
            )
          else
            item,
      ]);
    }

    final result = await ref
        .read(communityRepositoryProvider)
        .setMembership(community.slug, join: joining);

    if (result.failureOrNull != null) {
      state = before;
      return;
    }

    ref.invalidate(myCommunitiesProvider);
    ref.invalidate(suggestionsProvider);
    ref.invalidate(communityDetailProvider(community.slug));
  }
}

Future<void> afterFollowChanged(WidgetRef ref, String username) async {
  ref.invalidate(publicProfileProvider(username));
  ref.invalidate(suggestionsProvider);
  for (final kind in PeopleKind.values) {
    ref.invalidate(peopleProvider(kind));
  }
  await ref.read(authProvider.notifier).refreshUser();
}

final publicProfileProvider = FutureProvider.family<PublicProfile, String>((
  ref,
  username,
) async {
  final result = await ref.watch(communityRepositoryProvider).profile(username);
  final profile = result.valueOrNull;
  if (profile == null) {
    throw Exception(result.failureOrNull?.message ?? 'Not found');
  }
  return profile;
});
