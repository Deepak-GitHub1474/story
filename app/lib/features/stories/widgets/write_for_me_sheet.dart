import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_button.dart';
import '../../../components/app_sheet.dart';
import '../../../components/app_text_field.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/story_providers.dart';

typedef WrittenStory = ({String title, String body, String visibility});

Future<WrittenStory?> showWriteForMeSheet({
  required BuildContext context,
  required WidgetRef ref,
}) => showModalBottomSheet<WrittenStory>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => const _WriteForMe(),
);

class _WriteForMe extends ConsumerStatefulWidget {
  const _WriteForMe();

  @override
  ConsumerState<_WriteForMe> createState() => _WriteForMeState();
}

class _WriteForMeState extends ConsumerState<_WriteForMe> {
  final _subject = TextEditingController();
  final _brief = TextEditingController();

  String _visibility = 'draft';
  bool _isWriting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _brief.dispose();
    super.dispose();
  }

  Future<void> _write() async {
    setState(() {
      _isWriting = true;
      _error = null;
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .draft(subject: _subject.text.trim(), brief: _brief.text.trim());

    if (!mounted) return;
    setState(() => _isWriting = false);

    final written = result.valueOrNull;
    if (written == null) {
      setState(() => _error = result.failureOrNull?.message ?? 'That did not work.');
      return;
    }

    Navigator.of(context).pop((
      title: written.title,
      body: written.body,
      visibility: _visibility,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canWrite = _subject.text.trim().isNotEmpty && _brief.text.trim().isNotEmpty;

    return AppSheet(
      title: 'Write it with AI',
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Write it',
            isLoading: _isWriting,
            onPressed: canWrite && !_isWriting ? _write : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You see it before anything is published.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Say what it is about and what happened. It stays your story, in your '
          'words, and nothing is added that you did not say.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.label,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _subject,
          label: 'What is it about',
          hint: 'The day I left home',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _brief,
          label: 'What you want said',
          hint: 'Everything you remember, in any order. The messier the better.',
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Where it lands',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final option in const [
              ('draft', 'Draft'),
              ('private', 'Private'),
              ('public', 'Public'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _Choice(
                  label: option.$2,
                  isActive: _visibility == option.$1,
                  onTap: () => setState(() => _visibility = option.$1),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: colors.danger, fontSize: AppTypeScale.label),
          ),
        ],
      ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isActive ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? colors.accentText : colors.textSecondary,
            fontSize: AppTypeScale.label,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
