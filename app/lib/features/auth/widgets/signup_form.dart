import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/auth_provider.dart';
import 'auth_switch_link.dart';
import 'password_strength_bar.dart';
import 'terms_checkbox.dart';

class SignupForm extends ConsumerStatefulWidget {
  const SignupForm({super.key, required this.header, required this.onSwitch});

  final Widget header;
  final VoidCallback onSwitch;

  @override
  ConsumerState<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<SignupForm> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();

  Timer? _debounce;
  bool _tncAccepted = false;
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
      final result = await ref
          .read(authRepositoryProvider)
          .isUsernameAvailable(value);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = result.valueOrNull;
        _usernameError = result.failureOrNull?.message;
      });
    });
  }

  bool get _canSubmit =>
      _username.text.length >= 2 &&
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

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.header,
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _username,
                        label: 'Username',
                        hint: 'quiet_fox',
                        prefixIcon: Icons.person_outline,
                        errorText: _usernameAvailable == false
                            ? 'That username is already taken.'
                            : _usernameError,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-z0-9_-]'),
                          ),
                          LengthLimitingTextInputFormatter(30),
                        ],
                        onChanged: _onUsernameChanged,
                        suffix: _usernameMark(colors),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _password,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        errorText: _passwordError,
                        helperText: 'At least 10 characters.',
                        helperIcon: Icons.shield_outlined,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      PasswordStrengthBar(password: _password.text),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _referral,
                        label: 'Referral code (optional)',
                        hint: 'ABC123',
                        prefixIcon: Icons.card_giftcard_outlined,
                        errorText: _referralError,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TermsCheckbox(
                        value: _tncAccepted,
                        onChanged: (value) =>
                            setState(() => _tncAccepted = value),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: AppButton(
            label: 'Create account',
            isLoading: isBusy,
            onPressed: _canSubmit ? _submit : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: AuthSwitchLink(
            question: 'Already have an account?',
            action: 'Sign in',
            onTap: widget.onSwitch,
          ),
        ),
      ],
    );
  }

  Widget? _usernameMark(AppColors colors) {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          width: AppSizes.iconSm,
          height: AppSizes.iconSm,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_usernameAvailable != true) return null;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: AppSizes.iconSm,
            color: colors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Available',
            style: TextStyle(
              color: colors.success,
              fontSize: AppTypeScale.label,
            ),
          ),
        ],
      ),
    );
  }
}
