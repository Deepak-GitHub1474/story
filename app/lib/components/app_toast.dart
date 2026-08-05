import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum AppToastKind { info, error, success }

class AppToast {
  const AppToast._();

  static void show(BuildContext context, String message, {AppToastKind kind = AppToastKind.info}) {
    final colors = context.colors;
    final background = switch (kind) {
      AppToastKind.info => colors.surfaceRaised,
      AppToastKind.error => colors.danger,
      AppToastKind.success => colors.success,
    };
    final foreground = kind == AppToastKind.info ? colors.textPrimary : colors.bg;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: foreground)),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
  }
}
