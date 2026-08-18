import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../routing/router.dart';
import 'push_routes.dart';

final pushTapsProvider = Provider<void>((ref) {
  String? waiting;

  void open(String route) => ref.read(routerProvider).push(route);

  void handle(RemoteMessage? message) {
    if (message == null) return;

    final route = routeForPush(message.data);
    if (route == null) return;

    if (ref.read(authProvider).status == AuthStatus.signedIn) {
      open(route);
    } else {
      waiting = route;
    }
  }

  ref.listen(authProvider, (_, next) {
    final route = waiting;
    if (route != null && next.status == AuthStatus.signedIn) {
      waiting = null;
      open(route);
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then(handle);
  final tapped = FirebaseMessaging.onMessageOpenedApp.listen(handle);
  ref.onDispose(tapped.cancel);
});
