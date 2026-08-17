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
  required String subject,
  required String brief,
  void Function(WrittenDraft draft, String brief)? onDraft,
}) => showAppSheet<WrittenDraft>(
  context: context,
  initialSize: 0.92,
  minSize: 0.5,
  maxSize: 0.95,
  shell: (sheetContext, scrollController) => DraftPreviewSheet(
    title: title,
    body: body,
    subject: subject,
    brief: brief,
    onDraft: onDraft,
    scrollController: scrollController,
  ),
);

class DraftPreviewSheet extends ConsumerStatefulWidget {
  const DraftPreviewSheet({
    super.key,
    required this.title,
    required this.body,
    this.subject = '',
    this.brief = '',
    this.onDraft,
    this.scrollController,
  });

  final String title;
  final String body;
  final String subject;
  final String brief;
  final void Function(WrittenDraft draft, String brief)? onDraft;
  final ScrollController? scrollController;

  @override
  ConsumerState<DraftPreviewSheet> createState() => _DraftPreviewSheetState();
}

class _DraftPreviewSheetState extends ConsumerState<DraftPreviewSheet> {
  late String _title = widget.title;
  late String _body = widget.body;
  late String _brief = widget.brief;
  bool _isRefining = false;
  String? _error;
  ({String title, String body, String brief})? _before;

  void _stepBack() {
    final back = _before!;
    setState(() {
      _title = back.title;
      _body = back.body;
      _brief = back.brief;
      _before = null;
    });
    widget.onDraft?.call((title: back.title, body: back.body), back.brief);
  }

  Future<void> _refine() async {
    final asked = await showAppSheet<String>(
      context: context,
      title: 'What should change?',
      builder: (sheetContext) => _RefineInput(
        onSubmit: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );

    if (asked == null || asked.trim().isEmpty || !mounted) return;

    final brief = '$_brief\n\nChange this time: ${asked.trim()}';
    setState(() {
      _isRefining = true;
      _error = null;
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .draft(subject: widget.subject, brief: brief);

    if (!mounted) return;
    final written = result.valueOrNull;
    setState(() {
      _isRefining = false;
      _error = result.failureOrNull?.message;
      if (written != null) {
        _before = (title: _title, body: _body, brief: _brief);
        _title = written.title;
        _body = written.body;
        _brief = brief;
      }
    });

    if (written != null) {
      widget.onDraft?.call((title: written.title, body: written.body), brief);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppSheet(
      title: 'Read it first',
      scrollController: widget.scrollController,
      footer: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Ask for changes',
              variant: AppButtonVariant.outline,
              onPressed: _isRefining ? null : _refine,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: 'Use this',
              isLoading: _isRefining,
              onPressed: _isRefining
                  ? null
                  : () =>
                        Navigator.of(context).pop((title: _title, body: _body)),
            ),
          ),
        ],
      ),
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
          if (_before != null && !_isRefining) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _stepBack,
                child: Text(
                  'Back to the one before',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                    'Writing it again…',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.label,
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                _error!,
                style: TextStyle(
                  color: colors.danger,
                  fontSize: AppTypeScale.label,
                ),
              ),
            ),
          StoryText(text: _body, fontSize: AppTypeScale.reading),
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
