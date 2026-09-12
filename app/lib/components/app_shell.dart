import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/realtime/live_connection.dart';
import '../features/chat/providers/chat_providers.dart';
import '../features/notifications/providers/notification_providers.dart';
import '../routing/routes.dart';

import 'double_back_to_exit.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class ShellDestination {
  const ShellDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;

  ShellDestination withBadge(int count) => ShellDestination(
    route: route,
    label: label,
    icon: icon,
    activeIcon: activeIcon,
    badgeCount: count,
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.currentIndex,
    required this.onCompose,
  });

  final Widget child;
  final List<ShellDestination> destinations;
  final int currentIndex;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatIdentityProvider);
    ref.watch(liveBadgesProvider);
    ref.watch(liveConnectionProvider);

    final colors = context.colors;
    final unread = ref.watch(unreadCountProvider);
    final chatUnread = ref.watch(chatUnreadProvider).valueOrNull;

    return DoubleBackToExit(
      onBack: currentIndex == 0
          ? null
          : () {
              context.go(destinations[0].route);
              return true;
            },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: AppMotion.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.015),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(currentIndex), child: child),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.bg,
            border: Border(
              top: BorderSide(color: colors.border, width: AppSizes.hairline),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var index = 0; index < 2; index++)
                    Expanded(
                      child: _ShellTab(
                        destination: destinations[index],
                        isActive: index == currentIndex,
                        onTap: () => context.go(destinations[index].route),
                        badgeCount: switch (destinations[index].route) {
                          Routes.activity => unread,
                          Routes.chats =>
                            (chatUnread?.unread ?? 0) +
                                (chatUnread?.requests ?? 0),
                          _ => 0,
                        },
                      ),
                    ),
                  Expanded(child: _ComposeButton(onTap: onCompose)),
                  for (var index = 2; index < destinations.length; index++)
                    Expanded(
                      child: _ShellTab(
                        destination: destinations[index],
                        isActive: index == currentIndex,
                        onTap: () => context.go(destinations[index].route),
                        badgeCount: switch (destinations[index].route) {
                          Routes.activity => unread,
                          Routes.chats =>
                            (chatUnread?.unread ?? 0) +
                                (chatUnread?.requests ?? 0),
                          _ => 0,
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellTab extends StatelessWidget {
  const _ShellTab({
    required this.destination,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final ShellDestination destination;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isActive ? colors.accent : colors.textSecondary;

    return Semantics(
      label: destination.label,
      button: true,
      selected: isActive,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: AppSizes.iconNav,
                  height: AppSizes.iconNav,
                  child: Icon(
                    destination.icon,
                    color: color,
                    size: AppSizes.iconNav,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.bg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: AppTypeScale.micro,
                height: 1.1,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeButton extends StatefulWidget {
  const _ComposeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ComposeButton> createState() => _ComposeButtonState();
}

class _ComposeButtonState extends State<_ComposeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          child: Semantics(
            label: 'Write',
            button: true,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.accentStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: colors.accentText,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Write',
                    style: TextStyle(
                      fontSize: AppTypeScale.micro,
                      height: 1.1,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
