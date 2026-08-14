import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_button.dart';
import '../../../components/app_sheet.dart';
import '../../../components/app_text_field.dart';
import '../../../components/story_text.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/story_providers.dart';

typedef WrittenDraft = ({String title, String body});

Future<WrittenDraft?> showDraftPreview({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String body,
}) => showAppSheet<WrittenDraft>(
  context: context,
  isResizable: true,
  initialSize: 0.92,
  title: 'Read it first',
  builder: (_) => DraftPreviewSheet(title: title, body: body),
);

class DraftPreviewSheet extends ConsumerStatefulWidget {
  const DraftPreviewSheet({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  ConsumerState<DraftPreviewSheet> createState() => _DraftPreviewSheetState();
}

class _DraftPreviewSheetState extends ConsumerState<DraftPreviewSheet> {
  late final String _title = widget.title;
  late String _body = widget.body;
  bool _isRefining = false;

  Future<void> _refine() async {
    final asked = await showAppSheet<String>(
      context: context,
      title: 'What should change?',
      builder: (sheetContext) => _RefineInput(
        onSubmit: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );

    if (asked == null || asked.trim().isEmpty || !mounted) return;

    setState(() => _isRefining = true);
    final result = await ref
        .read(storyRepositoryProvider)
        .polish(text: _body, instruction: asked.trim());

    if (!mounted) return;
    final improved = result.valueOrNull;
    setState(() {
      _isRefining = false;
      if (improved != null) _body = improved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_title.isNotEmpty) ...[
            Text(
              _title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.title,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_isRefining)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Working on it…',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.label,
                    ),
                  ),
                ],
              ),
            ),
          StoryText(text: _body, fontSize: AppTypeScale.reading),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Use this',
            onPressed: _isRefining
                ? null
                : () => Navigator.of(context).pop((title: _title, body: _body)),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Ask for changes',
            variant: AppButtonVariant.outline,
            onPressed: _isRefining ? null : _refine,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _RefineInput extends StatefulWidget {
  const _RefineInput({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_RefineInput> createState() => _RefineInputState();
}

class _RefineInputState extends State<_RefineInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _controller,
            label: 'What should change?',
            hint: 'Make the middle shorter. Keep the ending.',
            maxLines: 4,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Rewrite it',
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => widget.onSubmit(_controller.text),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
