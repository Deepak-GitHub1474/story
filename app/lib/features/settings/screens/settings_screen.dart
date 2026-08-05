import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_card.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = ref.watch(themeProvider);
    final readingSize = ref.watch(readingSizeProvider);
    final user = ref.watch(authProvider).user;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.bg,
            surfaceTintColor: Colors.transparent,
            title: const Text('Settings'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            sliver: SliverList.list(
              children: [
                AppSection(
                  title: 'Appearance',
                  children: [
                    AppListRow(
                      label: 'Theme',
                      value: switch (theme) {
                        'midnight' => 'Midnight',
                        'paper' => 'Paper',
                        _ => 'System',
                      },
                      icon: Icons.contrast_outlined,
                      onTap: () => _pickTheme(context, ref, theme),
                    ),
                    AppListRow(
                      label: 'Reading size',
                      value: readingSize == 'readingLg' ? 'Large' : 'Normal',
                      icon: Icons.format_size_outlined,
                      onTap: () => ref
                          .read(readingSizeProvider.notifier)
                          .select(readingSize == 'readingLg' ? 'reading' : 'readingLg'),
                    ),
                  ],
                ),
                AppSection(
                  title: 'Account',
                  children: [
                    AppListRow(
                      label: 'Edit profile',
                      icon: Icons.person_outline,
                      onTap: () => context.push(Routes.editProfile),
                    ),
                    AppListRow(
                      label: 'Interests',
                      value: '${user?.interests.length ?? 0}',
                      icon: Icons.interests_outlined,
                      onTap: () => context.push(Routes.interests),
                    ),
                    AppListRow(
                      label: 'Change password',
                      icon: Icons.key_outlined,
                      onTap: () => context.push(Routes.changePassword),
                    ),
                    AppListRow(
                      label: 'Blocked accounts',
                      icon: Icons.block,
                      onTap: () => context.push(Routes.blocked),
                    ),
                    AppListRow(
                      label: 'Active sessions',
                      icon: Icons.devices_outlined,
                      onTap: () => context.push(Routes.sessions),
                    ),
                  ],
                ),
                AppSection(
                  title: 'About',
                  children: [
                    const AppListRow(
                      label: 'Version',
                      value: '0.1.0',
                      icon: Icons.info_outline,
                    ),
                    AppListRow(
                      label: 'Sign out',
                      icon: Icons.logout,
                      isDanger: true,
                      onTap: () => _confirmSignout(context, ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref, String current) async {
    final colors = context.colors;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final option in const [
              ('system', 'System'),
              ('midnight', 'Midnight'),
              ('paper', 'Paper'),
            ])
              AppListRow(
                label: option.$2,
                trailing: current == option.$1
                    ? Icon(Icons.check, color: colors.accent, size: AppSizes.iconMd)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.$1),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );

    if (choice != null) {
      await ref.read(themeProvider.notifier).select(choice);
    }
  }

  Future<void> _confirmSignout(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Sign out?'),
        content: const Text('You will need your username and password to come back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Stay', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Sign out', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(authProvider.notifier).signout();
    if (!context.mounted) return;
    AppToast.show(context, 'Signed out.');
    context.go(Routes.welcome);
  }
}
