import 'package:flutter/material.dart';

import '../../../components/app_sheet.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

const _points = [
  (
    Icons.person_outline,
    'You stay anonymous',
    'No real name, no phone number. Pick a username nobody can trace back to you.',
  ),
  (
    Icons.key_outlined,
    'Your password cannot be recovered',
    'Unless you add an email later, a forgotten password means a lost account. '
        'Nobody here can reset it for you.',
  ),
  (
    Icons.lock_outline,
    'Your vault opens with its passcode alone',
    'We never receive it, so nobody here can read what you keep there. Forget '
        'it and those files are gone for good.',
  ),
  (
    Icons.visibility_outlined,
    'You choose who reads a story',
    'Drafts and private stories stay with you. Anything public can be read and '
        'shared by anyone.',
  ),
  (
    Icons.delete_outline,
    'Deleting really deletes',
    'Removing a story erases its pictures from storage too. It does not come '
        'back.',
  ),
  (
    Icons.favorite_border,
    'Be kind here',
    'No harassment, no impersonation, nothing illegal. Accounts that do harm '
        'are removed.',
  ),
];

Future<void> showTermsSheet(BuildContext context) {
  final colors = context.colors;

  return showAppSheet<void>(
    context: context,
    title: 'Terms & Conditions',
    isResizable: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final point in _points) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    point.$1,
                    size: AppSizes.iconSm,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.$2,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppTypeScale.body,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        point.$3,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: AppTypeScale.label,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value ? colors.accentStrong : Colors.transparent,
                      border: Border.all(
                        color: value ? colors.accentStrong : colors.border,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: value
                        ? Icon(Icons.check, size: 16, color: colors.accentText)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'I accept the Terms & Conditions',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'What this means',
          icon: Icon(
            Icons.info_outline,
            size: AppSizes.iconMd,
            color: colors.textMuted,
          ),
          onPressed: () => showTermsSheet(context),
        ),
      ],
    );
  }
}
