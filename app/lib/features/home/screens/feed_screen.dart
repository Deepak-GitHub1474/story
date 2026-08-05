import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.bg,
            surfaceTintColor: Colors.transparent,
            title: const Text('STORY'),
            titleTextStyle: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            actions: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: AppAvatar(seed: user.avatarSeed, size: 32),
                ),
            ],
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 48,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Nothing here yet',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Stories and communities arrive in the next build. '
                    'Your account, profile, and settings are ready now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: AppTypeScale.body,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
