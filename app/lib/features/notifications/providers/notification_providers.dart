import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notification_repository.dart';
import '../models/notification_models.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(
    ref.watch(notificationRepositoryProvider),
    FirebaseMessaging.instance,
  ),
);

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() {
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    final result = await ref.read(notificationRepositoryProvider).unreadCount();
    state = result.valueOrNull ?? 0;
  }

  void decrement() {
    if (state > 0) state = state - 1;
  }

  void clear() => state = 0;
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends Notifier<AsyncValue<List<AppNotification>>> {
  @override
  AsyncValue<List<AppNotification>> build() {
    Future.microtask(refresh);
    return const AsyncValue.loading();
  }

  Future<void> refresh() async {
    final result = await ref.read(notificationRepositoryProvider).list();
    state = result.fold(
      onSuccess: (success) => AsyncValue.data(success.value),
      onFailure: (failure) => AsyncValue.error(failure.message, StackTrace.current),
    );
    await ref.read(unreadCountProvider.notifier).refresh();
  }

  Future<void> remove(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final gone = current.firstWhere((item) => item.notificationId == id);
    state = AsyncValue.data(
      current.where((item) => item.notificationId != id).toList(),
    );
    if (!gone.isRead) ref.read(unreadCountProvider.notifier).decrement();

    await ref.read(notificationRepositoryProvider).remove(id);
  }

  Future<void> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data([
      for (final item in current)
        if (item.notificationId == id) item.asRead() else item,
    ]);
    ref.read(unreadCountProvider.notifier).decrement();
    await ref.read(notificationRepositoryProvider).markRead(id);
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data([for (final item in current) item.asRead()]);
    }
    ref.read(unreadCountProvider.notifier).clear();
    await ref.read(notificationRepositoryProvider).markAllRead();
  }
}
