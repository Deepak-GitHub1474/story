import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class ShellDestination {
  const ShellDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
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
            height: 64,
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
                    ),
                  ),
              ],
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
  });

  final ShellDestination destination;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isActive ? colors.accent : colors.textMuted;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isActive ? 1.1 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            child: Icon(
              isActive ? destination.activeIcon : destination.icon,
              color: color,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: TextStyle(
              color: color,
              fontSize: AppTypeScale.caption,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(destination.label),
          ),
        ],
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
          child: Container(
            width: 52,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.edit_rounded,
              color: colors.accentText,
              size: AppSizes.iconMd,
            ),
          ),
        ),
      ),
    );
  }
}
