import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_strength_bar.dart';
import '../widgets/terms_checkbox.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();

  Timer? _debounce;
  bool _tncAccepted = false;
  bool _obscure = true;
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  String? _usernameError;
  String? _passwordError;
  String? _referralError;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _password.dispose();
    _referral.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    setState(() {
      _usernameAvailable = null;
      _usernameError = null;
    });
    _debounce?.cancel();
    if (value.length < 3) return;

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _checkingUsername = true);
      final result = await ref.read(authRepositoryProvider).isUsernameAvailable(value);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = result.valueOrNull;
        _usernameError = result.failureOrNull?.message;
      });
    });
  }

  bool get _canSubmit =>
      _username.text.length >= 3 &&
      _password.text.length >= 10 &&
      _tncAccepted &&
      _usernameAvailable != false;

  Future<void> _submit() async {
    setState(() {
      _usernameError = null;
      _passwordError = null;
      _referralError = null;
    });

    final failure = await ref
        .read(authProvider.notifier)
        .signup(
          username: _username.text.trim().toLowerCase(),
          password: _password.text,
          tncAccepted: _tncAccepted,
          referralCode: _referral.text.trim().toUpperCase(),
        );

    if (!mounted) return;

    if (failure == null) {
      context.go(Routes.onboardingInterests);
      return;
    }

    setState(() {
      switch (failure.field) {
        case 'username':
          _usernameError = failure.message;
        case 'password':
          _passwordError = failure.message;
        case 'referral_code':
          _referralError = failure.message;
        default:
          break;
      }
    });

    if (failure.field == null) {
      AppToast.show(context, failure.message, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isBusy = ref.watch(authProvider).isBusy;

    return AppScaffold(
      title: 'Create your account',
      leading: BackButton(onPressed: () => context.pop()),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a name nobody can trace back to you.',
              style: TextStyle(color: colors.textSecondary, fontSize: AppTypeScale.body),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _username,
              label: 'Username',
              hint: 'quiet_fox',
              autofocus: true,
              errorText: _usernameAvailable == false
                  ? 'That username is already taken.'
                  : _usernameError,
              helperText: _usernameAvailable == true ? 'Available.' : null,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                LengthLimitingTextInputFormatter(20),
              ],
              onChanged: _onUsernameChanged,
              suffix: _checkingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: SizedBox(
                        width: AppSizes.iconSm,
                        height: AppSizes.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: _obscure,
              errorText: _passwordError,
              helperText: 'At least 10 characters. Never recoverable, so keep it safe.',
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: colors.textMuted,
                  size: AppSizes.iconMd,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PasswordStrengthBar(password: _password.text),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _referral,
              label: 'Referral code (optional)',
              hint: 'ABC123',
              errorText: _referralError,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            TermsCheckbox(
              value: _tncAccepted,
              onChanged: (value) => setState(() => _tncAccepted = value),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Create account',
              isLoading: isBusy,
              onPressed: _canSubmit ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
