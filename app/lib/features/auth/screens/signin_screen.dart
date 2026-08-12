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

class SigninScreen extends ConsumerStatefulWidget {
  const SigninScreen({super.key});

  @override
  ConsumerState<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends ConsumerState<SigninScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  String? _formError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit => _username.text.isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() => _formError = null);

    final failure = await ref
        .read(authProvider.notifier)
        .signin(
          username: _username.text.trim().toLowerCase(),
          password: _password.text,
        );

    if (!mounted) return;

    if (failure == null) {
      context.go(Routes.home);
      return;
    }

    if (failure.code == 'INVALID_CREDENTIALS') {
      setState(() => _formError = failure.message);
    } else {
      AppToast.show(context, failure.message, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isBusy = ref.watch(authProvider).isBusy;

    return AppScaffold(
      padding: EdgeInsets.zero,
      alignment: Alignment.topCenter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 46),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: 215,
                        child: Text(
                          'Your stories are where you left them.',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: AppTypeScale.body,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _username,
                        label: 'Username',
                        hint: 'quiet_fox',
                        prefixIcon: Icons.person_outline,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-z0-9_]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _password,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _canSubmit ? _submit() : null,
                      ),
                      if (_formError != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.danger),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text(
                            _formError!,
                            style: TextStyle(
                              color: colors.danger,
                              fontSize: AppTypeScale.label,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => context.push(Routes.forgotPassword),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: AppTypeScale.label,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Sign in',
                        isLoading: isBusy,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: Text(
                          'Your privacy is our priority.',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.label,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: AppSizes.iconSm,
                              color: colors.accent,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'No tracking. No real names. Just you and your story.',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: AppTypeScale.label,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 46,
            right: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/bloom.png',
                width: 176,
                height: 236,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 46,
              color: colors.bg,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
