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

class SigninForm extends ConsumerStatefulWidget {
  const SigninForm({super.key, required this.header});

  final Widget header;

  @override
  ConsumerState<SigninForm> createState() => _SigninFormState();
}

class _SigninFormState extends ConsumerState<SigninForm> {
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
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-z0-9_]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                      const SizedBox(height: AppSpacing.lg),
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
            AppSpacing.xl,
          ),
          child: AppButton(
            label: 'Log in',
            isLoading: isBusy,
            onPressed: _canSubmit ? _submit : null,
          ),
        ),
      ],
    );
  }
}
