import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/recovery_repository.dart';
import '../models/recovery_models.dart';

final recoveryRepositoryProvider = Provider<RecoveryRepository>(
  (ref) => RecoveryRepository(ref.watch(apiClientProvider)),
);

final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final result = await ref.watch(recoveryRepositoryProvider).tickets();
  return result.valueOrNull ?? const [];
});

final securityActivityProvider = FutureProvider<List<SecurityEvent>>((ref) async {
  final result = await ref.watch(recoveryRepositoryProvider).securityActivity();
  return result.valueOrNull ?? const [];
});
