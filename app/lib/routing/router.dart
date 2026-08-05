import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_shell.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/signin_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/home/screens/feed_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/stories/screens/composer_screen.dart';
import '../features/stories/screens/story_detail_screen.dart';
import '../features/onboarding/screens/interests_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/change_password_screen.dart';
import '../features/settings/screens/edit_profile_screen.dart';
import '../features/settings/screens/sessions_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import 'routes.dart';
import 'transitions.dart';

const shellDestinations = [
  ShellDestination(
    route: Routes.feed,
    label: 'Feed',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories,
  ),
  ShellDestination(
    route: Routes.activity,
    label: 'Activity',
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
  ),
  ShellDestination(
    route: Routes.profile,
    label: 'You',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
  ShellDestination(
    route: Routes.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
  ),
];

int _shellIndex(String location) {
  final index = shellDestinations.indexWhere(
    (destination) => location.startsWith(destination.route),
  );
  return index < 0 ? 0 : index;
}

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
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) =>
            fadePage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: Routes.welcome,
        pageBuilder: (context, state) =>
            fadePage(key: state.pageKey, child: const WelcomeScreen()),
      ),
      GoRoute(
        path: Routes.signup,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const SignupScreen()),
      ),
      GoRoute(
        path: Routes.signin,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const SigninScreen()),
      ),
      GoRoute(
        path: Routes.compose,
        pageBuilder: (context, state) => sheetPage(
          key: state.pageKey,
          child: ComposerScreen(storyId: state.uri.queryParameters['id']),
        ),
      ),
      GoRoute(
        path: '${Routes.story}/:storyId',
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: StoryDetailScreen(storyId: state.pathParameters['storyId']!),
        ),
      ),
      GoRoute(
        path: Routes.editProfile,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const EditProfileScreen()),
      ),
      GoRoute(
        path: Routes.interests,
        pageBuilder: (context, state) =>
            sheetPage(key: state.pageKey, child: const InterestsScreen()),
      ),
      GoRoute(
        path: Routes.changePassword,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const ChangePasswordScreen()),
      ),
      GoRoute(
        path: Routes.sessions,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const SessionsScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          destinations: shellDestinations,
          currentIndex: _shellIndex(state.matchedLocation),
          onCompose: () => context.push(Routes.compose),
          child: child,
        ),
        routes: [
          GoRoute(
            path: Routes.feed,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const FeedScreen()),
          ),
          GoRoute(
            path: Routes.activity,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: Routes.profile,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const ProfileScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const SettingsScreen()),
          ),
        ],
      ),
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
        return Routes.feed;
      }
      return null;
    },
  );
});
