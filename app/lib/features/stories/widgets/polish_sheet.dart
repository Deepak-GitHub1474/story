import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_button.dart';
import '../../../components/app_sheet.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/story_providers.dart';

const _ideas = [
  'Fix the spelling and grammar',
  'Make it shorter',
  'Break it into paragraphs',
  'Keep it simple and plain',
];

typedef PolishDraft = void Function(String text, int rounds);

Future<bool?> showPolishSheet({
  required BuildContext context,
  required String text,
  required PolishDraft onDraft,
  String? startFrom,
  int startRounds = 0,
}) => showAppSheet<bool>(
  context: context,
  initialSize: 0.7,
  minSize: 0.5,
  maxSize: 0.95,
  shell: (sheetContext, scrollController) => PolishSheet(
    text: text,
    onDraft: onDraft,
    startFrom: startFrom,
    startRounds: startRounds,
    scrollController: scrollController,
  ),
);

class PolishSheet extends ConsumerStatefulWidget {
  const PolishSheet({
    super.key,
    required this.text,
    required this.onDraft,
    this.startFrom,
    this.startRounds = 0,
    this.scrollController,
  });

  final String text;
  final PolishDraft onDraft;
  final String? startFrom;
  final int startRounds;
  final ScrollController? scrollController;

  @override
  ConsumerState<PolishSheet> createState() => _PolishSheetState();
}

class _PolishSheetState extends ConsumerState<PolishSheet> {
  final _instruction = TextEditingController();
  bool _isBusy = false;
  String? _error;
  String? _result;
  String? _before;
  int _rounds = 0;

  @override
  void initState() {
    super.initState();
    _result = widget.startFrom;
    _rounds = widget.startFrom == null ? 0 : widget.startRounds;
  }

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  bool get _canRun => !_isBusy && _instruction.text.trim().isNotEmpty;

  Future<void> _run() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .polish(
          text: _result ?? widget.text,
          instruction: _instruction.text.trim(),
        );

    if (!mounted) return;
    final next = result.valueOrNull;
    setState(() {
      _isBusy = false;
      _error = result.failureOrNull?.message;
      if (next != null) {
        _before = _result;
        _result = next;
        _rounds += 1;
        _instruction.clear();
      }
    });
    if (next != null) widget.onDraft(next, _rounds);
  }

  void _stepBack() {
    final back = _before!;
    setState(() {
      _result = back;
      _before = null;
      _rounds -= 1;
    });
    widget.onDraft(back, _rounds);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppSheet(
      title: 'Another go at it',
      scrollController: widget.scrollController,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border, width: AppSizes.hairline),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _instruction,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _result == null
                          ? 'Say what should change'
                          : 'Ask for one more change',
                      hintStyle: TextStyle(color: colors.textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_canRun) _run();
                    },
                  ),
                ),
                IconButton(
                  tooltip: _result == null ? 'Show me' : 'Change it again',
                  icon: _isBusy
                      ? const SizedBox(
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          color: _canRun ? colors.accent : colors.textMuted,
                        ),
                  onPressed: _canRun ? _run : null,
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Keep mine',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Use this version',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Say what you want changed. It stays your story, in your words — '
            'nothing is added and nothing is softened.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AppTypeScale.label,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final idea in _ideas)
                InkWell(
                  onTap: () => setState(() => _instruction.text = idea),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.border,
                        width: AppSizes.hairline,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      idea,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                  ),
                ),
            ],
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
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _rounds == 1
                        ? 'One change in. Ask for another and it builds on this.'
                        : '$_rounds changes in, each one on top of the last.',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                ),
                if (_before != null)
                  TextButton(
                    onPressed: _isBusy ? null : _stepBack,
                    child: Text(
                      'Undo that one',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: AppTypeScale.caption,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.border,
                  width: AppSizes.hairline,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _result!,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.reading,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
