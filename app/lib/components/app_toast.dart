import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum AppToastKind { info, error, success }

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.info,
    IconData? icon,
  }) {
    final colors = context.colors;
    final background = switch (kind) {
      AppToastKind.info => colors.surfaceRaised,
      AppToastKind.error => colors.danger,
      AppToastKind.success => colors.success,
    };
    final foreground = kind == AppToastKind.info
        ? colors.textPrimary
        : colors.bg;
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: AppSizes.iconSm),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: messenger.hideCurrentSnackBar,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.close,
                    color: foreground,
                    size: AppSizes.iconSm,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
  }
}
