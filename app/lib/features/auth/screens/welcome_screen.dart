import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

const _promises = [
  (Icons.shield_outlined, 'Private by design', 'Your story stays yours.'),
  (Icons.masks_outlined, 'Completely anonymous', 'No real names. No pressure.'),
  (Icons.favorite_border, 'Find your people', 'Stories connect us.'),
];

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            right: -28,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/bloom.png',
                width: 196,
                height: 300,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'STORY',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: AppTypeScale.heading,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: 285,
                    child: Text(
                      'Say the thing you cannot say anywhere else.',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 30,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: 250,
                    child: Text(
                      'A private space for your untold stories.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.body,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final promise in _promises)
                        Expanded(child: _Promise(promise: promise)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppButton(
                    label: 'Create an account',
                    onPressed: () => context.push(Routes.signup),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'I already have one',
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.push(Routes.signin),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Text(
                      'Your privacy is our priority.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.label,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: AppSizes.iconSm,
                          color: colors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'No tracking. No real names. Just you and your story.',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.promise});

  final (IconData, String, String) promise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(promise.$1, size: AppSizes.iconMd, color: colors.accent),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          promise.$2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          promise.$3,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.caption,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
