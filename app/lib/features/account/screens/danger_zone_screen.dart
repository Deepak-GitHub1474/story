import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

class DangerZoneScreen extends ConsumerStatefulWidget {
  const DangerZoneScreen({super.key});

  @override
  ConsumerState<DangerZoneScreen> createState() => _DangerZoneScreenState();
}

class _DangerZoneScreenState extends ConsumerState<DangerZoneScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _isBusy = false;
  String? _error;

  static const _confirmWord = 'DELETE';

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _deactivate() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(accountRepositoryProvider)
        .deactivate(_password.text);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      ref.read(authProvider.notifier).markSignedOut();
      AppToast.show(context, 'Account deactivated.');
      context.go(Routes.welcome);
    } else {
      setState(() => _error = result.failureOrNull!.message);
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(accountRepositoryProvider)
        .requestDeletion(_password.text);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      ref.read(authProvider.notifier).markSignedOut();
      AppToast.show(context, 'Deletion scheduled. Sign in to cancel.');
      context.go(Routes.welcome);
    } else {
      setState(() => _error = result.failureOrNull!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Leaving',
      leading: BackButton(onPressed: () => context.pop()),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: true,
              errorText: _error,
              helperText: 'Required for both actions below.',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _Section(
              title: 'Deactivate',
              body: 'Your stories and profile are hidden. Sign in any time to '
                  'bring everything back exactly as it was.',
              action: AppButton(
                label: 'Deactivate account',
                variant: AppButtonVariant.secondary,
                isLoading: _isBusy,
                onPressed: _password.text.isEmpty ? null : _deactivate,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _Section(
              title: 'Delete',
              body: 'Scheduled for 14 days from now. Sign in before then to '
                  'cancel. After that, everything is gone and your username '
                  'is released.',
              isDanger: true,
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _confirm,
                    label: 'Type $_confirmWord to confirm',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Delete account',
                    variant: AppButtonVariant.secondary,
                    isLoading: _isBusy,
                    onPressed:
                        _password.text.isEmpty || _confirm.text.trim() != _confirmWord
                        ? null
                        : _delete,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    required this.action,
    this.isDanger = false,
  });

  final String title;
  final String body;
  final Widget action;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: isDanger ? colors.danger : colors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDanger ? colors.danger : colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          action,
        ],
      ),
    );
  }
}
