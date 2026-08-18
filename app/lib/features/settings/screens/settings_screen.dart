import 'dart:math';

import 'package:flutter/material.dart';

import '../../../components/app_back_button.dart';

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
import '../../notifications/providers/notification_providers.dart';
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
              leading: const AppBackButton(),
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
                          'blush' => 'Blush pink',
                          'maroon' => 'Maroon',
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
                            .select(
                              readingSize == 'readingLg'
                                  ? 'reading'
                                  : 'readingLg',
                            ),
                      ),
                    ],
                  ),
                  AppSection(
                    children: [
                      AppListRow(
                        label: 'Vault',
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
                        trailing: _PrefSwitch(
                          value: user?.prefs['notify_in_app'] as bool? ?? true,
                          onChanged: (value) =>
                              _savePref(ref, 'notify_in_app', value),
                        ),
                      ),
                      AppListRow(
                        label: 'On my phone',
                        icon: Icons.phone_iphone_outlined,
                        trailing: _PrefSwitch(
                          value: user?.prefs['notify_push'] as bool? ?? false,
                          onChanged: (value) async {
                            final push = ref.read(pushServiceProvider);
                            if (value) {
                              final problem = await push.enable();
                              if (problem != null) {
                                if (context.mounted) {
                                  AppToast.show(
                                    context,
                                    problem,
                                    kind: AppToastKind.error,
                                  );
                                }
                                return false;
                              }
                            } else {
                              await push.disable();
                            }
                            return _savePref(ref, 'notify_push', value);
                          },
                        ),
                      ),
                      const AppListRow(
                        label: 'Only when the app is closed, so nothing arrives twice.',
                        icon: Icons.info_outline,
                      ),
                    ],
                  ),
                  AppSection(
                    title: 'Chat',
                    children: [
                      AppListRow(
                        label: 'Show when I am online',
                        icon: Icons.circle_outlined,
                        trailing: _PrefSwitch(
                          value:
                              user?.prefs['show_online_status'] as bool? ??
                              true,
                          onChanged: (value) =>
                              _savePref(ref, 'show_online_status', value),
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
                                  AppToast.show(
                                    context,
                                    'Referral code copied.',
                                  );
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

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final colors = context.colors;
    final choice = await showAppSheet<String>(
      context: context,
      title: 'Themes',
      contentPadding: const EdgeInsets.only(top: AppSpacing.md),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in const [
            ('system', 'System', AppColors.paper, AppColors.midnight),
            ('paper', 'Light', AppColors.paper, null),
            ('midnight', 'Dark', AppColors.midnight, null),
            ('blush', 'Blush pink', AppColors.blush, null),
            ('maroon', 'Maroon', AppColors.maroon, null),
          ])
            AppListRow(
              label: option.$2,
              leadingWidget: _Swatch(colors: option.$3, second: option.$4),
              trailing: current == option.$1
                  ? Icon(
                      Icons.check,
                      color: colors.accent,
                      size: AppSizes.iconMd,
                    )
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(option.$1),
            ),
        ],
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
      body:
          'Every device signs out, including this one. Useful if you think '
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

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors, this.second});

  final AppColors colors;
  final AppColors? second;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(AppSizes.iconMd),
    painter: _SwatchPainter(colors: colors, second: second),
  );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.colors, this.second});

  final AppColors colors;
  final AppColors? second;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 0.5;
    final dot = size.width / 4.8;

    final left = Rect.fromCircle(center: centre, radius: radius);
    final other = second ?? colors;

    canvas.drawArc(left, -pi / 2, pi, true, Paint()..color = colors.bg);
    canvas.drawArc(left, pi / 2, pi, true, Paint()..color = other.bg);

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: dot),
      -pi / 2,
      pi,
      true,
      Paint()..color = colors.accent,
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: dot),
      pi / 2,
      pi,
      true,
      Paint()..color = other.accent,
    );

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.colors != colors || old.second != second;
}

Future<bool> _savePref(WidgetRef ref, String key, bool value) async {
  final result = await ref
      .read(profileRepositoryProvider)
      .updateProfile(prefs: {key: value});
  final user = result.valueOrNull;
  if (user == null) return false;
  ref.read(authProvider.notifier).adoptUser(user);
  return true;
}

class _PrefSwitch extends StatefulWidget {
  const _PrefSwitch({required this.value, required this.onChanged});

  final bool value;
  final Future<bool> Function(bool value) onChanged;

  @override
  State<_PrefSwitch> createState() => _PrefSwitchState();
}

class _PrefSwitchState extends State<_PrefSwitch> {
  bool? _wanted;

  @override
  void didUpdateWidget(covariant _PrefSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _wanted = null;
  }

  Future<void> _flip(bool next) async {
    setState(() => _wanted = next);
    final stuck = await widget.onChanged(next);
    if (!mounted) return;
    setState(() => _wanted = stuck ? next : null);
  }

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: _wanted ?? widget.value,
      activeThumbColor: context.colors.accent,
      onChanged: _flip,
    );
  }
}
