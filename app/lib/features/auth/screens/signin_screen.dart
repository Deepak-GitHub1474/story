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

  bool _obscure = true;
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

    final failure = await ref.read(authProvider.notifier).signin(
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
      title: 'Welcome back',
      leading: BackButton(onPressed: () => context.pop()),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _username,
              label: 'Username',
              autofocus: true,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                LengthLimitingTextInputFormatter(20),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _canSubmit ? _submit() : null,
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: colors.textMuted,
                  size: AppSizes.iconMd,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
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
                  style: TextStyle(color: colors.danger, fontSize: AppTypeScale.label),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(Routes.forgotPassword),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(color: colors.accent, fontSize: AppTypeScale.label),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Sign in',
              isLoading: isBusy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
