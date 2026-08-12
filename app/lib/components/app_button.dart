import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDisabled = onPressed == null || isLoading;

    final background = switch (variant) {
      AppButtonVariant.primary => colors.accentStrong,
      AppButtonVariant.secondary => colors.surfaceRaised,
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.outline => Colors.transparent,
    };

    final foreground = switch (variant) {
      AppButtonVariant.primary => colors.accentText,
      AppButtonVariant.secondary => colors.textPrimary,
      AppButtonVariant.ghost => colors.accent,
      AppButtonVariant.outline => colors.accent,
    };

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: AppSizes.controlHeight,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            side: variant == AppButtonVariant.outline
                ? BorderSide(color: colors.accent)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: AppTypeScale.body,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
