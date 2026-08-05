import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? colors.accent : Colors.transparent,
                border: Border.all(color: value ? colors.accent : colors.border, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: value
                  ? Icon(Icons.check, size: 16, color: colors.accentText)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'I accept the terms and understand that a forgotten password cannot be '
                'recovered without an email on the account.',
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
    );
  }
}
