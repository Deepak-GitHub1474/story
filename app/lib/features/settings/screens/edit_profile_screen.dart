import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _displayName;
  late final TextEditingController _bio;

  bool _isSaving = false;
  String? _displayNameError;
  String? _bioError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _displayName = TextEditingController(text: user?.displayName ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _displayNameError = null;
      _bioError = null;
    });

    final result = await ref.read(profileRepositoryProvider).updateProfile(
      displayName: _displayName.text.trim(),
      bio: _bio.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final failure = result.failureOrNull;
    if (failure == null) {
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.show(context, 'Profile updated.', kind: AppToastKind.success);
      context.pop();
      return;
    }

    setState(() {
      if (failure.field == 'bio') {
        _bioError = failure.message;
      } else if (failure.field == 'display_name') {
        _displayNameError = failure.message;
      }
    });
    if (failure.field == null) {
      AppToast.show(context, failure.message, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit profile',
      leading: BackButton(onPressed: () => context.pop()),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _displayName,
              label: 'Display name',
              hint: 'Quiet Fox',
              errorText: _displayNameError,
              helperText: 'Shown on your stories. Change it whenever you like.',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _bio,
              label: 'Bio',
              hint: 'Say as little as you want.',
              errorText: _bioError,
              helperText: 'Up to 200 characters. Links are not allowed.',
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Save',
              isLoading: _isSaving,
              onPressed: _displayName.text.trim().isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
