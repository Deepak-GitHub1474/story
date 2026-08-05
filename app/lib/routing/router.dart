import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/signin_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/home/screens/home_screen.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier(ref.read(authProvider).status);

  ref.listen(authProvider, (previous, next) {
    if (previous?.status != next.status) notifier.value = next.status;
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: notifier,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
      GoRoute(path: Routes.signin, builder: (_, _) => const SigninScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    ],
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final location = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return location == Routes.splash ? null : Routes.splash;
      }

      const publicRoutes = {Routes.welcome, Routes.signup, Routes.signin};

      if (status == AuthStatus.signedOut) {
        return publicRoutes.contains(location) ? null : Routes.welcome;
      }

      if (publicRoutes.contains(location) || location == Routes.splash) {
        return Routes.home;
      }
      return null;
    },
  );
});
