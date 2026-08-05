import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_card.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.bg,
            surfaceTintColor: Colors.transparent,
            title: const Text('You'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push(Routes.editProfile),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            sliver: SliverList.list(
              children: [
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onLongPress: () async {
                          final result = await ref
                              .read(profileRepositoryProvider)
                              .regenerateAvatar();
                          if (!context.mounted) return;
                          if (result.isSuccess) {
                            await ref.read(authProvider.notifier).refreshUser();
                            if (!context.mounted) return;
                            AppToast.show(context, 'New avatar.');
                          }
                        },
                        child: Hero(
                          tag: 'avatar-${user.userId}',
                          child: AppAvatar(seed: user.avatarSeed, size: 88),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        user.displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: AppTypeScale.title,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: AppTypeScale.body,
                        ),
                      ),
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: AppTypeScale.reading,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Long-press the avatar for a new one.',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: AppTypeScale.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    _Stat(label: 'Stories', value: '${user.counts['stories'] ?? 0}'),
                    _Stat(label: 'Following', value: '${user.counts['connections'] ?? 0}'),
                    _Stat(label: 'Followers', value: '${user.counts['followers'] ?? 0}'),
                  ],
                ),
                if (user.interests.isNotEmpty) ...[
                  AppSection(
                    title: 'Interests',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final slug in user.interests)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  slug.replaceAll('-', ' '),
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: AppTypeScale.label,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                AppSection(
                  title: 'Invite',
                  children: [
                    AppListRow(
                      label: 'Your referral code',
                      value: user.referralCode,
                      icon: Icons.card_giftcard_outlined,
                    ),
                    if (user.referredBy != null)
                      AppListRow(
                        label: 'Referred by',
                        value: user.referredBy,
                        icon: Icons.handshake_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(color: colors.textMuted, fontSize: AppTypeScale.caption),
          ),
        ],
      ),
    );
  }
}
