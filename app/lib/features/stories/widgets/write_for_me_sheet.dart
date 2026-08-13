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

  final String _visibility = 'draft';
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
      setState(
        () => _error = result.failureOrNull?.message ?? 'That did not work.',
      );
      return;
    }

    Navigator.of(
      context,
    ).pop((title: written.title, body: written.body, visibility: _visibility));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canWrite =
        _subject.text.trim().isNotEmpty && _brief.text.trim().isNotEmpty;

    return AppSheet(
      title: 'Write it with AI',
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      footer: AppButton(
        label: 'Write it',
        isLoading: _isWriting,
        onPressed: canWrite && !_isWriting ? _write : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
            hint:
                'Everything you remember, in any order. The messier the better.',
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(
                color: colors.danger,
                fontSize: AppTypeScale.label,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
