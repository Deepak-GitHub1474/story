import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  static const _minLength = 10;

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= _minLength) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'\s').hasMatch(password.trim())) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) score++;
    return score.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = _score;
    final label = switch (score) {
      0 => '',
      1 => 'Short',
      2 => 'Okay',
      3 => 'Strong',
      _ => 'Very strong',
    };
    final color = switch (score) {
      0 || 1 => colors.danger,
      2 => colors.textSecondary,
      _ => colors.success,
    };

    return Row(
      children: [
        for (var index = 0; index < 4; index++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: index < score ? color : colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (index < 3) const SizedBox(width: AppSpacing.xs),
        ],
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: AppTypeScale.caption),
          ),
        ),
      ],
    );
  }
}
