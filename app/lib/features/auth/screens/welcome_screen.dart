import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/bloom_mark.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

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
            child: const BloomMark(width: 196, height: 300),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
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
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
