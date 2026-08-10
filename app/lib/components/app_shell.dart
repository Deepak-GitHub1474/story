import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    this.isAvatar = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;
  final bool isAvatar;

  ShellDestination withBadge(int count) => ShellDestination(
    route: route,
    label: label,
    icon: icon,
    activeIcon: activeIcon,
    badgeCount: count,
    isAvatar: isAvatar,
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
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: _ShellTab(
                    destination: destinations[0],
                    isActive: currentIndex == 0,
                    onTap: () => context.go(destinations[0].route),
                  ),
                ),
                _ComposeButton(onTap: onCompose),
                for (var index = 1; index < destinations.length; index++)
                  Expanded(
                    child: _ShellTab(
                      destination: destinations[index],
                      isActive: index == currentIndex,
                      onTap: () => context.go(destinations[index].route),
                      badgeCount: switch (destinations[index].route) {
                        Routes.activity => unread,
                        Routes.chats =>
                          (chatUnread?.unread ?? 0) + (chatUnread?.requests ?? 0),
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
    final color = isActive ? colors.accent : colors.textMuted;

    return Semantics(
      label: destination.label,
      button: true,
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Stack(
              clipBehavior: Clip.none,
              children: [
                if (destination.isAvatar)
                  Container(
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: isActive ? 2 : 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isActive ? destination.activeIcon : destination.icon,
                      color: color,
                      size: AppSizes.iconMd - 8,
                    ),
                  )
                else
                  Icon(
                    isActive ? destination.activeIcon : destination.icon,
                    color: color,
                    size: AppSizes.iconMd,
                  ),
                if (badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
              width: 52,
              height: 40,
              child: Icon(
                Icons.add_box_outlined,
                color: colors.textMuted,
                size: AppSizes.iconMd,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
