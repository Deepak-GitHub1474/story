import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/providers/chat_providers.dart';
import '../../features/notifications/providers/notification_providers.dart';

final liveConnectionProvider = Provider<void>((ref) {
  final listener = AppLifecycleListener(
    onResume: () {
      unawaited(ref.read(realtimeProvider).connect());
      ref.invalidate(chatUnreadProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(conversationsProvider(null));
      ref.invalidate(conversationsProvider('pending'));
    },
    onPause: () => unawaited(ref.read(realtimeProvider).sleep()),
    onDetach: () => unawaited(ref.read(realtimeProvider).sleep()),
  );

  ref.onDispose(listener.dispose);
});
