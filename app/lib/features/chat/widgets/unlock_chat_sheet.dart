import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_providers.dart';

class UnlockChatSheet extends ConsumerStatefulWidget {
  const UnlockChatSheet({super.key});

  @override
  ConsumerState<UnlockChatSheet> createState() => _UnlockChatSheetState();
}

class _UnlockChatSheetState extends ConsumerState<UnlockChatSheet> {
  final _password = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final userId = ref.read(authProvider).user?.userId;
    if (userId == null) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    final ok = await ref
        .read(chatBootstrapProvider)
        .unlockOnThisDevice(userId: userId, password: _password.text);

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _error = ok ? null : 'That password did not open your messages.';
    });

    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl + insets,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your messages are locked to your devices, not to our servers. '
            'Type your password once and this phone can read them again, '
            'including everything from before.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _password,
            label: 'Account password',
            obscureText: true,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Unlock messages',
            isLoading: _isBusy,
            onPressed: _password.text.isEmpty ? null : _unlock,
          ),
        ],
      ),
    );
  }
}
