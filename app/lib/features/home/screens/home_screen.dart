import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const AppScaffold(child: Center(child: CircularProgressIndicator()));
    }

    return AppScaffold(
      title: 'You',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(seed: user.avatarSeed, size: 64),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: AppTypeScale.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: AppTypeScale.label,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          _InfoRow(label: 'Your referral code', value: user.referralCode),
          _InfoRow(label: 'Referred by', value: user.referredBy ?? 'Nobody'),
          _InfoRow(label: 'Role', value: user.role),
          _InfoRow(label: 'Status', value: user.blocked ? 'Blocked' : user.status),
          const Spacer(),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await ref.read(authProvider.notifier).signout();
              if (!context.mounted) return;
              AppToast.show(context, 'Signed out.');
              context.go(Routes.welcome);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: AppTypeScale.body),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
