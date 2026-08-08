import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../components/otp_field.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();

  bool _isBusy = false;
  bool _awaitingOtp = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(accountRepositoryProvider)
        .addEmail(_email.text.trim());

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      setState(() => _awaitingOtp = true);
    } else {
      setState(() => _error = result.failureOrNull!.message);
    }
  }

  Future<void> _verify(String otp) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref.read(accountRepositoryProvider).verifyEmail(otp);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.isSuccess) {
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.show(context, 'Email verified.', kind: AppToastKind.success);
      context.pop();
    } else {
      setState(() {
        _error = result.failureOrNull!.message;
        _otp.clear();
      });
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Remove your email?'),
        content: const Text(
          'Without an email on the account, a forgotten password cannot be '
          'recovered. Your account would be gone for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Remove', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(accountRepositoryProvider)
        .removeEmail(_password.text);

    if (!mounted) return;
    if (result.isSuccess) {
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.show(context, 'Email removed.');
      context.pop();
    } else {
      setState(() => _error = result.failureOrNull!.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(authProvider).user;
    final hasEmail = user?.emailMasked != null;

    return AppScaffold(
      title: 'Recovery email',
      leading: BackButton(onPressed: () => context.pop()),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'An email is the only way to recover a forgotten password. '
                'We store it encrypted and can never show it to you or anyone '
                'else, only send to it.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.label,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (hasEmail && !_awaitingOtp) ...[
              Row(
                children: [
                  Icon(
                    user!.emailVerified ? Icons.verified : Icons.error_outline,
                    color: user.emailVerified ? colors.success : colors.textMuted,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    user.emailMasked!,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.emailVerified ? 'Verified.' : 'Not verified yet.',
                style: TextStyle(color: colors.textMuted, fontSize: AppTypeScale.caption),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _password,
                label: 'Password',
                obscureText: true,
                errorText: _error,
                helperText: 'Confirm it is you before removing the address.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Remove email',
                variant: AppButtonVariant.secondary,
                onPressed: _password.text.isEmpty ? null : _remove,
              ),
            ] else if (_awaitingOtp) ...[
              Text(
                'Enter the 6-digit code we sent.',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.body,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OtpField(
                controller: _otp,
                hasError: _error != null,
                onCompleted: _verify,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: colors.danger, fontSize: AppTypeScale.caption),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () async {
                  final result = await ref
                      .read(accountRepositoryProvider)
                      .resendOtp();
                  if (!context.mounted) return;
                  AppToast.show(
                    context,
                    result.isSuccess
                        ? 'Another code sent.'
                        : result.failureOrNull!.message,
                    kind: result.isSuccess
                        ? AppToastKind.info
                        : AppToastKind.error,
                  );
                },
                child: Text('Send another code', style: TextStyle(color: colors.accent)),
              ),
            ] else ...[
              AppTextField(
                controller: _email,
                label: 'Email address',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _error,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send code',
                isLoading: _isBusy,
                onPressed: _email.text.contains('@') ? _send : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
