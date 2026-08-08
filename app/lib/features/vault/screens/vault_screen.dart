import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_sheet.dart';

import '../../../components/app_button.dart';
import '../../../components/app_card.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_text_field.dart';
import '../../../components/app_toast.dart';
import '../../../components/confirm_dialog.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/security/secure_screen.dart';
import '../../../routing/routes.dart';
import '../../../components/skeleton.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../data/file_kind.dart';
import '../data/vault_selection.dart';
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
  String? _chosenVaultId;
  VaultItem? _found;
  String? _kindFilter;

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
        .unlock(
          password: _password.text,
          passcode: _passcode.text,
          passcodeId: _chosenVaultId,
        );

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

  Future<void> _newVault() async {
    final created = await showAppSheet<bool>(
      context: context,
      title: 'New vault',
      builder: (sheetContext) => const _NewVaultSheet(),
    );

    if (created == true && mounted) {
      ref.invalidate(vaultOverviewProvider);
      AppToast.show(context, 'Vault created.', kind: AppToastKind.success);
    }
  }

  Future<void> _addFile() async {
    final file = await FilePicking.pick();
    if (file == null || !mounted) return;

    final kind = detectKind(file.bytes, file.name);
    if (kind == null) {
      AppToast.show(
        context,
        'The vault holds photos, videos, and PDFs. That file is neither.',
        kind: AppToastKind.error,
      );
      return;
    }

    final label = await showAppSheet<String?>(
      context: context,
      builder: (sheetContext) => _HideSheet(filename: file.name),
    );

    if (!mounted) return;

    final ok = await ref.read(vaultUploadProvider.notifier).addFile(
      bytes: file.bytes,
      filename: file.name,
      kind: kind,
      label: label,
    );

    if (!mounted) return;
    AppToast.show(
      context,
      ok
          ? 'Encrypted on this device and stored.'
          : ref.read(vaultUploadProvider).error ?? 'Could not store that file.',
      kind: ok ? AppToastKind.success : AppToastKind.error,
    );
  }

  Future<void> _openItem(VaultItem item) async {
    final bytes = await ref.read(vaultUploadProvider.notifier).openItem(item);
    if (!mounted) return;

    if (bytes == null) {
      final drop = await confirmAction(
        context,
        title: 'This one cannot be opened',
        body: 'It was locked with keys that no longer exist, so nothing can '
            'read it now. Removing it frees the space it is using.',
        confirmLabel: 'Remove it',
        cancelLabel: 'Keep it',
      );
      if (drop && mounted) await _removeItem(item, isConfirmed: true);
      return;
    }

    AppToast.show(
      context,
      'Opened on this device. ${bytes.length ~/ 1024} KB decrypted.',
      kind: AppToastKind.success,
    );
  }

  Future<void> _removeItem(VaultItem item, {bool isConfirmed = false}) async {
    if (!isConfirmed) {
      final sure = await confirmAction(
        context,
        title: 'Remove this file?',
        body: 'It leaves the vault for good. Nobody can bring it back.',
        confirmLabel: 'Remove',
        cancelLabel: 'Keep',
      );
      if (!sure || !mounted) return;
    }

    await ref.read(vaultRepositoryProvider).deleteItem(item.itemId);
    ref.invalidate(vaultItemsProvider);
    ref.invalidate(vaultOverviewProvider);
    if (mounted) setState(() => _found = null);
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

    final vaults = vaultsOnly(overview.valueOrNull?.passcodes ?? const []);
    final chosenId = _chosenVaultId ?? vaults.firstOrNull?.passcodeId;

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
              if (vaults.length > 1) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Which vault',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: AppTypeScale.caption,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in vaults)
                      _VaultChip(
                        label: entry.label,
                        isChosen: entry.passcodeId == chosenId,
                        onTap: () =>
                            setState(() => _chosenVaultId = entry.passcodeId),
                      ),
                  ],
                ),
              ],
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
                  'You have not set up a vault yet.',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: AppTypeScale.caption,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Set up your vault',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(Routes.vaultSetup),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final items = ref.watch(vaultItemsProvider);
    final upload = ref.watch(vaultUploadProvider);

    return AppScaffold(
      title: session.label ?? 'Vault',
      leading: BackButton(
        onPressed: () {
          ref.read(vaultSessionProvider.notifier).lock();
          context.pop();
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.add, color: colors.textPrimary),
          onPressed: upload.isBusy ? null : _addFile,
        ),
        IconButton(
          icon: Icon(Icons.create_new_folder_outlined, color: colors.textMuted),
          onPressed: upload.isBusy ? null : _newVault,
        ),
        IconButton(
          icon: Icon(Icons.lock_outline, color: colors.textMuted),
          onPressed: () {
            ref.read(vaultSessionProvider.notifier).lock();
            setState(() => _found = null);
          },
        ),
        IconButton(
          icon: Icon(Icons.help_outline, color: colors.textMuted),
          onPressed: () => context.push(Routes.vaultRecovery),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upload.isBusy) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: upload.progress == 0 ? null : upload.progress,
                backgroundColor: colors.surfaceRaised,
                color: colors.accent,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Encrypting and uploading. Nothing leaves in plain form.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: AppTypeScale.caption,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
            label: 'Find a sealed file',
            hint: 'Type its secret word',
            helperText: 'Exact match, capitals included. Sealed files are in no list.',
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchHidden(),
          ),
          if (_found != null) ...[
            const SizedBox(height: AppSpacing.md),
            VaultTile(
              item: _found!,
              isHiddenResult: true,
              onTap: () => _openItem(_found!),
              onRemove: () => _removeItem(_found!),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _KindTabs(
            selected: _kindFilter,
            onSelect: (kind) => setState(() => _kindFilter = kind),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: items.when(
              loading: () => const SkeletonList(count: 4),
              error: (error, _) => Center(
                child: Text(
                  'Could not load your vault.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              data: (list) {
                final shown = _kindFilter == null
                    ? list
                    : list.where((item) => item.kind == _kindFilter).toList();
                return shown.isEmpty
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Photos, videos, and PDFs. Each one is encrypted on '
                              'this device before it leaves. We receive ciphertext '
                              'and no filename.',
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
                      itemCount: shown.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) => VaultTile(
                        item: shown[index],
                        onTap: () => _openItem(shown[index]),
                        onRemove: () => _removeItem(shown[index]),
                      ),
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _HideSheet extends StatefulWidget {
  const _HideSheet({required this.filename});

  final String filename;

  @override
  State<_HideSheet> createState() => _HideSheetState();
}

class _HideSheetState extends State<_HideSheet> {
  final _label = TextEditingController();
  bool _isHidden = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: AppTypeScale.heading,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The filename is encrypted too. We store neither it nor the contents.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.caption,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SwitchListTile.adaptive(
            value: _isHidden,
            onChanged: (value) => setState(() => _isHidden = value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: colors.accent,
            title: Text(
              'Seal this file',
              style: TextStyle(color: colors.textPrimary),
            ),
            subtitle: Text(
              'A sealed file never appears in any tab. It is found only by '
              'typing its secret word exactly, capitals and all.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: AppTypeScale.caption,
              ),
            ),
          ),
          if (_isHidden) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _label,
              label: 'Secret word',
              hint: 'Something only you would type',
              helperText: 'Case matters. Forget it and the file is gone for good.',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Store in vault',
            onPressed: _isHidden && _label.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_isHidden ? _label.text : null),
          ),
        ],
      ),
    );
  }
}


class _KindTabs extends StatelessWidget {
  const _KindTabs({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  static const _tabs = [
    (null, 'All', Icons.grid_view_outlined),
    ('image', 'Photos', Icons.image_outlined),
    ('video', 'Videos', Icons.videocam_outlined),
    ('pdf', 'PDFs', Icons.picture_as_pdf_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        for (final (kind, label, icon) in _tabs) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(kind),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.easeOut,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: selected == kind ? colors.accent : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected == kind ? colors.accent : colors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: AppSizes.iconSm,
                      color: selected == kind
                          ? colors.accentText
                          : colors.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected == kind
                            ? colors.accentText
                            : colors.textSecondary,
                        fontSize: AppTypeScale.caption,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (kind != 'pdf') const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _VaultChip extends StatelessWidget {
  const _VaultChip({
    required this.label,
    required this.isChosen,
    required this.onTap,
  });

  final String label;
  final bool isChosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isChosen ? colors.accent : Colors.transparent,
          border: Border.all(color: isChosen ? colors.accent : colors.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: AppSizes.iconSm,
              color: isChosen ? colors.accentText : colors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: isChosen ? colors.accentText : colors.textSecondary,
                fontSize: AppTypeScale.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewVaultSheet extends ConsumerStatefulWidget {
  const _NewVaultSheet();

  @override
  ConsumerState<_NewVaultSheet> createState() => _NewVaultSheetState();
}

class _NewVaultSheetState extends ConsumerState<_NewVaultSheet> {
  final _name = TextEditingController();
  final _passcode = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _passcode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final ok = await ref
        .read(vaultSessionProvider.notifier)
        .createPasscode(
          password: '',
          passcode: _passcode.text,
          label: _name.text.trim(),
        );

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _error = ok ? null : 'That vault could not be created.';
    });

    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final isReady = _name.text.trim().isNotEmpty && _passcode.text.length >= 8;

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
            'A second vault has its own passcode. Nothing in one opens the '
            'other, and forgetting a passcode loses only that vault.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _name,
            label: 'Name it',
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _passcode,
            label: 'Its passcode',
            obscureText: true,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Create vault',
            isLoading: _isBusy,
            onPressed: isReady ? _create : null,
          ),
        ],
      ),
    );
  }
}
