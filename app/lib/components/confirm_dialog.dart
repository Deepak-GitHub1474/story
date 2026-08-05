import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = true,
  List<String> consequences = const [],
}) async {
  final colors = context.colors;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? colors.danger : colors.textPrimary,
          fontSize: AppTypeScale.heading,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.body,
              height: 1.55,
            ),
          ),
          if (consequences.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            for (final line in consequences)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.remove,
                      size: AppSizes.iconSm,
                      color: isDestructive ? colors.danger : colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.label,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            cancelLabel,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDestructive ? colors.danger : colors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}
