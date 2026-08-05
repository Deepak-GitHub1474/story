import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/account_repository.dart';
import '../../auth/data/profile_repository.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/providers/auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiClientProvider)),
);

final interestsProvider = FutureProvider<List<InterestOption>>((ref) async {
  final result = await ref.watch(profileRepositoryProvider).interests();
  return result.valueOrNull ?? const [];
});

final sessionsProvider = FutureProvider<List<SessionInfo>>((ref) async {
  final result = await ref.watch(profileRepositoryProvider).sessions();
  return result.valueOrNull ?? const [];
});
