import 'package:flutter/material.dart';

import '../../../components/app_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_card.dart';
import '../../../components/app_toast.dart';
import '../../../components/confirm_dialog.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = ref.watch(themeProvider);
    final readingSize = ref.watch(readingSizeProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.bg,
            surfaceTintColor: Colors.transparent,
            leading: BackButton(onPressed: () => context.pop()),
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
                        'midnight' => 'Dark',
                        'paper' => 'Light',
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
                  title: 'Vault',
                  children: [
                    AppListRow(
                      label: 'Open vault',
                      icon: Icons.lock_outline,
                      onTap: () => context.push(Routes.vault),
                    ),
                  ],
                ),
                AppSection(
                  title: 'Notifications',
                  children: [
                    AppListRow(
                      label: 'In-app notifications',
                      icon: Icons.notifications_outlined,
                      trailing: Switch.adaptive(
                        value: user?.prefs['notify_in_app'] as bool? ?? true,
                        activeThumbColor: colors.accent,
                        onChanged: (value) async {
                          await ref
                              .read(profileRepositoryProvider)
                              .updateProfile(prefs: {'notify_in_app': value});
                          await ref.read(authProvider.notifier).refreshUser();
                        },
                      ),
                    ),
                  ],
                ),
                AppSection(
                  title: 'Chat',
                  children: [
                    AppListRow(
                      label: 'Show when I am online',
                      icon: Icons.circle_outlined,
                      trailing: Switch.adaptive(
                        value: user?.prefs['show_online_status'] as bool? ?? true,
                        activeThumbColor: colors.accent,
                        onChanged: (value) async {
                          await ref
                              .read(profileRepositoryProvider)
                              .updateProfile(prefs: {'show_online_status': value});
                          await ref.read(authProvider.notifier).refreshUser();
                        },
                      ),
                    ),
                    const AppListRow(
                      label: 'Turning this off also hides theirs from you.',
                      icon: Icons.info_outline,
                    ),
                  ],
                ),
                AppSection(
                  title: 'Account',
                  children: [
                    AppListRow(
                      label: 'Choose your avatar',
                      icon: Icons.face_outlined,
                      onTap: () => context.push(Routes.avatar),
                    ),
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
                      label: 'Recovery email',
                      value: user?.emailMasked ?? 'Not set',
                      icon: Icons.alternate_email,
                      onTap: () => context.push(Routes.email),
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
                    AppListRow(
                      label: 'Your referral code',
                      value: user?.referralCode,
                      icon: Icons.card_giftcard_outlined,
                      onTap: user == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: user.referralCode),
                              );
                              if (context.mounted) {
                                AppToast.show(context, 'Referral code copied.');
                              }
                            },
                    ),
                    if (user?.referredBy != null)
                      AppListRow(
                        label: 'Referred by',
                        value: user!.referredBy,
                        icon: Icons.people_outline,
                      ),
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
                    AppListRow(
                      label: 'Sign out everywhere',
                      icon: Icons.devices_other_outlined,
                      isDanger: true,
                      onTap: () => _confirmSignoutAll(context, ref),
                    ),
                    AppListRow(
                      label: 'Deactivate or delete',
                      icon: Icons.person_off_outlined,
                      isDanger: true,
                      onTap: () => context.push(Routes.dangerZone),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref, String current) async {
    final colors = context.colors;
    final choice = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              ('system', 'System'),
              ('midnight', 'Dark'),
              ('paper', 'Light'),
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

  Future<void> _confirmSignoutAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out everywhere?',
      body: 'Every device signs out, including this one. Useful if you think '
          'someone else has your account.',
      confirmLabel: 'Sign out everywhere',
      cancelLabel: 'Stay',
    );

    if (!confirmed || !context.mounted) return;

    await ref.read(authProvider.notifier).signoutEverywhere();
    if (!context.mounted) return;
    AppToast.show(context, 'Signed out on every device.');
    context.go(Routes.welcome);
  }

  Future<void> _confirmSignout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      body: 'You will need your username and password to come back.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay',
    );

    if (!confirmed || !context.mounted) return;

    await ref.read(authProvider.notifier).signout();
    if (!context.mounted) return;
    AppToast.show(context, 'Signed out.');
    context.go(Routes.welcome);
  }
}
