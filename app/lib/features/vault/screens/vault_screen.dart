import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_card.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../core/security/secure_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/vault_models.dart';
import '../providers/vault_providers.dart';
import '../widgets/vault_tile.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _password = TextEditingController();
  final _passcode = TextEditingController();
  final _label = TextEditingController();

  bool _isBusy = false;
  String? _error;
  VaultItem? _found;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _password.dispose();
    _passcode.dispose();
    _label.dispose();
    ref.read(vaultSessionProvider.notifier).lock();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final ok = await ref
        .read(vaultSessionProvider.notifier)
        .unlock(password: _password.text, passcode: _passcode.text);

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _error = ok ? null : ref.read(vaultSessionProvider).error;
    });

    if (ok) {
      _password.clear();
      _passcode.clear();
      ref.invalidate(vaultItemsProvider);
    }
  }

  Future<void> _searchHidden() async {
    final hash = await ref.read(vaultSessionProvider.notifier).hashLabel(_label.text);
    if (hash == null || !mounted) return;

    final result = await ref.read(vaultRepositoryProvider).findByLabel(hash);
    if (!mounted) return;

    setState(() => _found = result.valueOrNull);
    if (result.valueOrNull == null) {
      AppToast.show(context, 'Nothing found.', kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(vaultSessionProvider);
    final overview = ref.watch(vaultOverviewProvider);

    if (!session.isUnlocked) {
      return AppScaffold(
        title: 'Vault',
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
                  'Two secrets open this vault: your account password and your vault '
                  'passcode. We hold neither. Nothing here can be read by us, by '
                  'staff, or by anyone with our database.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppTypeScale.label,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _password,
                label: 'Account password',
                obscureText: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _passcode,
                label: 'Vault passcode',
                obscureText: true,
                errorText: _error,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Unlock',
                isLoading: _isBusy,
                onPressed:
                    _password.text.isEmpty || _passcode.text.isEmpty ? null : _unlock,
              ),
              if (overview.valueOrNull?.hasPasscode == false) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No vault passcode yet. Set one up from Settings before you can '
                  'store anything.',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: AppTypeScale.caption,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final items = ref.watch(vaultItemsProvider);

    return AppScaffold(
      title: 'Vault',
      leading: BackButton(
        onPressed: () {
          ref.read(vaultSessionProvider.notifier).lock();
          context.pop();
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.lock_outline, color: colors.textMuted),
          onPressed: () {
            ref.read(vaultSessionProvider.notifier).lock();
            setState(() => _found = null);
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overview.valueOrNull != null)
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${overview.value!.itemCount} items · '
                      '${(overview.value!.usedBytes / 1048576).toStringAsFixed(1)} MB used',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _label,
            label: 'Find a hidden item',
            hint: 'Type the exact label',
            helperText: 'Exact match only. There is no list of hidden items.',
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchHidden(),
          ),
          if (_found != null) ...[
            const SizedBox(height: AppSpacing.md),
            VaultTile(item: _found!, isHiddenResult: true),
          ],
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Could not load your vault.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 44,
                              color: colors.textMuted,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Nothing stored yet',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: AppTypeScale.heading,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Files are encrypted on this device before they leave '
                              'it. We receive ciphertext and no filename.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: AppTypeScale.body,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) => VaultTile(item: list[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
