import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'STORY',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.title,
              fontWeight: FontWeight.w600,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Say the thing you cannot say anywhere else.',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.title,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No email. No phone. No real name. Nobody here knows who you are, '
            'and that is the point.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.reading,
              height: 1.6,
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Create an account',
            onPressed: () => context.push(Routes.signup),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'I already have one',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(Routes.signin),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
