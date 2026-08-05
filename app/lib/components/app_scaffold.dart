import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: title == null && leading == null
          ? null
          : AppBar(title: title == null ? null : Text(title!), leading: leading, actions: actions),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
