import 'package:flutter/material.dart';

import '../../../components/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_card.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_toast.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/settings_provider.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  IconData _icon(String platform) => switch (platform) {
    'android' => Icons.android,
    'ios' => Icons.phone_iphone,
    _ => Icons.language,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sessions = ref.watch(sessionsProvider);

    return AppScaffold(
      title: 'Active sessions',
      leading: const AppBackButton(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Could not load your sessions.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        data: (items) => ListView(
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Every device signed in to this account. Revoking one signs it out '
              'within a minute.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AppTypeScale.label,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final session in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(
                        _icon(session.platform),
                        color: session.isCurrent ? colors.accent : colors.textMuted,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.label,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.body,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              session.isCurrent ? 'This device' : 'Signed in',
                              style: TextStyle(
                                color: session.isCurrent
                                    ? colors.success
                                    : colors.textMuted,
                                fontSize: AppTypeScale.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!session.isCurrent)
                        TextButton(
                          onPressed: () async {
                            final result = await ref
                                .read(profileRepositoryProvider)
                                .revokeSession(session.familyId);
                            if (!context.mounted) return;
                            if (result.isSuccess) {
                              ref.invalidate(sessionsProvider);
                              AppToast.show(context, 'Session signed out.');
                            }
                          },
                          child: Text(
                            'Revoke',
                            style: TextStyle(color: colors.danger),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
