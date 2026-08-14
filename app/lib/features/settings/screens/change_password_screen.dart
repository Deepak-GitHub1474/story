import 'package:flutter/material.dart';

import '../../../components/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/password_strength_bar.dart';
import '../../chat/providers/chat_providers.dart';
import '../providers/settings_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();

  bool _isSaving = false;
  String? _currentError;
  String? _nextError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  bool get _canSubmit => _current.text.isNotEmpty && _next.text.length >= 10;

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _currentError = null;
      _nextError = null;
    });

    final result = await ref
        .read(profileRepositoryProvider)
        .changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final failure = result.failureOrNull;
    if (failure == null) {
      final userId = ref.read(authProvider).user?.userId;
      final carried = userId == null
          ? true
          : await ref.read(chatBootstrapProvider).rewrapBackup(
              userId: userId,
              currentPassword: _current.text,
              newPassword: _next.text,
            );

      if (!mounted) return;
      AppToast.show(
        context,
        carried
            ? 'Password changed.'
            : 'Password changed, but your chats could not be carried over.',
        kind: carried ? AppToastKind.success : AppToastKind.error,
      );
      context.pop();
      return;
    }

    setState(() {
      if (failure.field == 'new_password') {
        _nextError = failure.message;
      } else {
        _currentError = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      title: 'Change password',
      leading: const AppBackButton(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(
                  color: colors.border,
                  width: AppSizes.hairline,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Changing your password keeps you signed in and keeps your account intact. '
                'It is not the same as resetting a forgotten password.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.label,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _current,
              label: 'Current password',
              obscureText: true,
              errorText: _currentError,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _next,
              label: 'New password',
              obscureText: true,
              errorText: _nextError,
              helperText: 'At least 10 characters.',
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            PasswordStrengthBar(password: _next.text),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Change password',
              isLoading: _isSaving,
              onPressed: _canSubmit ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
