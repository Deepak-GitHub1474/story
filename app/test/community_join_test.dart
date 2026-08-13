import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/features/communities/data/community_repository.dart';
import 'package:story_app/features/communities/models/community_models.dart';
import 'package:story_app/features/communities/providers/community_providers.dart';

Community room(String slug, {required bool isMember, int members = 10}) =>
    Community(
      slug: slug,
      name: slug,
      description: '',
      categoryId: 'grief',
      members: members,
      stories: 0,
      isMember: isMember,
    );

class FakeCommunities implements CommunityRepository {
  FakeCommunities();

  final joined = <String>{};
  int suggestionCalls = 0;
  int mineCalls = 0;
  int detailCalls = 0;
  bool refuse = false;

  @override
  Future<Result<Suggestions>> suggestions() async {
    suggestionCalls++;
    return Success(
      Suggestions(
        communities: [
          for (final slug in ['grief-room', 'night-shift'])
            if (!joined.contains(slug)) room(slug, isMember: false),
        ],
        people: const [],
      ),
    );
  }

  @override
  Future<Result<List<Category>>> categories() async => Success(const []);

  @override
  Future<Result<List<Community>>> mine() async {
    mineCalls++;
    return Success([for (final slug in joined) room(slug, isMember: true)]);
  }

  @override
  Future<Result<List<Community>>> browse({
    String? category,
    String? query,
  }) async => Success([
    for (final slug in ['grief-room', 'night-shift'])
      room(slug, isMember: joined.contains(slug)),
  ]);

  @override
  Future<Result<Community>> detail(String slug) async {
    detailCalls++;
    return Success(room(slug, isMember: joined.contains(slug)));
  }

  @override
  Future<Result<Community>> setMembership(
    String slug, {
    required bool join,
  }) async {
    if (refuse) {
      return const Failure(code: 'NOPE', message: 'no');
    }
    join ? joined.add(slug) : joined.remove(slug);
    return Success(room(slug, isMember: join));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer containerWith(FakeCommunities fake) {
  final container = ProviderContainer(
    overrides: [communityRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('joining drops the room from the recommendations', () async {
    final fake = FakeCommunities();
    final container = containerWith(fake);

    final before = await container.read(suggestionsProvider.future);
    expect(before.communities.map((c) => c.slug), contains('grief-room'));

    await container
        .read(communityBrowseProvider.notifier)
        .toggleMembership(room('grief-room', isMember: false));

    final after = await container.read(suggestionsProvider.future);
    expect(
      after.communities.map((c) => c.slug),
      isNot(contains('grief-room')),
      reason: 'a room you just joined is no longer a recommendation',
    );
  });

  test('joining refreshes the room own screen', () async {
    final fake = FakeCommunities();
    final container = containerWith(fake);

    final before = await container.read(
      communityDetailProvider('grief-room').future,
    );
    expect(before.isMember, isFalse);

    await container
        .read(communityBrowseProvider.notifier)
        .toggleMembership(room('grief-room', isMember: false));

    final after = await container.read(
      communityDetailProvider('grief-room').future,
    );
    expect(
      after.isMember,
      isTrue,
      reason: 'walking into the room must not ask you to join again',
    );
  });

  test('joining refreshes the list of rooms you belong to', () async {
    final fake = FakeCommunities();
    final container = containerWith(fake);

    expect(await container.read(myCommunitiesProvider.future), isEmpty);

    await container
        .read(communityBrowseProvider.notifier)
        .toggleMembership(room('grief-room', isMember: false));

    final mine = await container.read(myCommunitiesProvider.future);
    expect(mine.map((c) => c.slug), contains('grief-room'));
  });

  test('leaving puts the room back among the recommendations', () async {
    final fake = FakeCommunities()..joined.add('grief-room');
    final container = containerWith(fake);

    await container
        .read(communityBrowseProvider.notifier)
        .toggleMembership(room('grief-room', isMember: true));

    final after = await container.read(suggestionsProvider.future);
    expect(after.communities.map((c) => c.slug), contains('grief-room'));
  });

  test('a refused join leaves every cache alone', () async {
    final fake = FakeCommunities()..refuse = true;
    final container = containerWith(fake);

    await container.read(suggestionsProvider.future);
    final callsBefore = fake.suggestionCalls;

    await container
        .read(communityBrowseProvider.notifier)
        .toggleMembership(room('grief-room', isMember: false));

    final after = await container.read(suggestionsProvider.future);
    expect(after.communities.map((c) => c.slug), contains('grief-room'));
    expect(
      fake.suggestionCalls,
      callsBefore,
      reason: 'nothing was refetched because nothing changed',
    );
  });
}
