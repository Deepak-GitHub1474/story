import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_shell.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/home/screens/feed_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/account/screens/danger_zone_screen.dart';
import '../features/account/screens/email_screen.dart';
import '../features/account/screens/forgot_password_screen.dart';
import '../features/communities/screens/communities_screen.dart';
import '../features/people/screens/people_list_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/communities/screens/community_detail_screen.dart';
import '../features/communities/screens/public_profile_screen.dart';
import '../features/stories/screens/composer_screen.dart';
import '../features/stories/screens/story_detail_screen.dart';
import '../features/onboarding/screens/interests_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/avatar_screen.dart';
import '../features/settings/screens/change_password_screen.dart';
import '../features/settings/screens/edit_profile_screen.dart';
import '../features/settings/screens/sessions_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/vault/screens/recovery_screen.dart';
import '../features/vault/screens/vault_screen.dart';
import 'routes.dart';
import 'transitions.dart';

const shellDestinations = [
  ShellDestination(
    route: Routes.stories,
    label: 'Story',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories,
  ),
  ShellDestination(
    route: Routes.activity,
    label: 'Notifications',
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
  ),
  ShellDestination(
    route: Routes.chats,
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
  ),
  ShellDestination(
    route: Routes.profile,
    label: 'You',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
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
            fadePage(key: state.pageKey, child: const AuthScreen()),
      ),
      GoRoute(
        path: Routes.signup,
        pageBuilder: (context, state) => fadePage(
          key: state.pageKey,
          child: const AuthScreen(initialTab: AuthTab.signup),
        ),
      ),
      GoRoute(
        path: Routes.signin,
        pageBuilder: (context, state) => fadePage(
          key: state.pageKey,
          child: const AuthScreen(initialTab: AuthTab.login),
        ),
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
        path: Routes.communities,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const CommunitiesScreen()),
      ),
      GoRoute(
        path: '${Routes.community}/:slug',
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: CommunityDetailScreen(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '${Routes.user}/:username',
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: PublicProfileScreen(username: state.pathParameters['username']!),
        ),
      ),
      GoRoute(
        path: Routes.search,
        pageBuilder: (context, state) =>
            fadePage(
              key: state.pageKey,
              child: SearchScreen(
                peopleOnly: state.uri.queryParameters['people'] == '1',
              ),
            ),
      ),
      GoRoute(
        path: Routes.following,
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: const PeopleListScreen(kind: PeopleKind.following),
        ),
      ),
      GoRoute(
        path: Routes.followers,
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: const PeopleListScreen(kind: PeopleKind.followers),
        ),
      ),
      GoRoute(
        path: Routes.blocked,
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: const PeopleListScreen(kind: PeopleKind.blocked),
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: Routes.email,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const EmailScreen()),
      ),
      GoRoute(
        path: Routes.vault,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const VaultScreen()),
      ),
      GoRoute(
        path: Routes.vaultRecovery,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const RecoveryScreen()),
      ),
      GoRoute(
        path: Routes.dangerZone,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const DangerZoneScreen()),
      ),
      GoRoute(
        path: Routes.editProfile,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const EditProfileScreen()),
      ),
      GoRoute(
        path: Routes.onboardingInterests,
        pageBuilder: (context, state) => fadePage(
          key: state.pageKey,
          child: const InterestsScreen(isOnboarding: true),
        ),
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
            path: Routes.stories,
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
            path: Routes.chats,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const ChatListScreen()),
          ),
          GoRoute(
            path: Routes.profile,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '${Routes.chat}/:conversationId',
        pageBuilder: (context, state) => slidePage(
          key: state.pageKey,
          child: ChatScreen(
            conversationId: state.pathParameters['conversationId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.avatar,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const AvatarScreen()),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (context, state) =>
            slidePage(key: state.pageKey, child: const SettingsScreen()),
      ),
    ],
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final location = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return location == Routes.splash ? null : Routes.splash;
      }

      const publicRoutes = {
        Routes.welcome,
        Routes.signup,
        Routes.signin,
        Routes.forgotPassword,
      };

      if (status == AuthStatus.signedOut) {
        return publicRoutes.contains(location) ? null : Routes.welcome;
      }

      if (publicRoutes.contains(location) || location == Routes.splash) {
        return Routes.stories;
      }
      if (location == Routes.onboardingInterests) return null;
      return null;
    },
  );
});
