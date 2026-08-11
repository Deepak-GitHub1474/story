import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../core/security/secure_screen.dart';
import '../data/vault_selection.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/vault_providers.dart';

class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen> {
  final _passcode = TextEditingController();
  final _confirm = TextEditingController();

  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _passcode.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!isStrongPasscode(_passcode.text)) {
      setState(
        () => _error = 'Use at least $passcodeMinLength characters, with '
            'letters as well as numbers.',
      );
      return;
    }
    if (_passcode.text.trim() != _confirm.text.trim()) {
      setState(() => _error = 'Those two passcodes are not the same.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    final ok = await ref
        .read(vaultSessionProvider.notifier)
        .createPasscode(passcode: _passcode.text.trim());

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (!ok) {
      setState(() => _error = 'Could not set up your vault. Check your password.');
      return;
    }

    ref.invalidate(vaultOverviewProvider);
    AppToast.show(context, 'Vault ready.', kind: AppToastKind.success);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSubmit =
        _passcode.text.isNotEmpty && _confirm.text.isNotEmpty;

    return AppScaffold(
      title: 'Set up your vault',
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
                'One secret opens your vault: the passcode you choose now. We never '
                'receive it, so nobody here can open your files. Forget it and they '
                'are gone for good, so make it something you will not lose.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.label,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _passcode,
              label: 'Vault passcode',
              obscureText: true,
              helperText: 'At least $passcodeMinLength characters. A short phrase '
                  'works better than a word.',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _confirm,
              label: 'Repeat vault passcode',
              obscureText: true,
              errorText: _error,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Create vault',
              isLoading: _isBusy,
              onPressed: canSubmit ? _create : null,
            ),
          ],
        ),
      ),
    );
  }
}
