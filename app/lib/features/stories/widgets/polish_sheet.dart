import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/story_providers.dart';

const _ideas = [
  'Fix the spelling and grammar',
  'Make it shorter',
  'Break it into paragraphs',
  'Keep it simple and plain',
];

class PolishSheet extends ConsumerStatefulWidget {
  const PolishSheet({super.key, required this.text});

  final String text;

  @override
  ConsumerState<PolishSheet> createState() => _PolishSheetState();
}

class _PolishSheetState extends ConsumerState<PolishSheet> {
  final _instruction = TextEditingController();
  bool _isBusy = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    final result = await ref
        .read(storyRepositoryProvider)
        .polish(text: widget.text, instruction: _instruction.text.trim());

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _result = result.valueOrNull;
      _error = result.failureOrNull?.message;
    });
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
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _instruction,
            label: 'What should change',
            errorText: _error,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.border,
                  width: AppSizes.hairline,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.reading,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Use this version',
              onPressed: () => Navigator.of(context).pop(_result),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Keep mine',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Show me',
              isLoading: _isBusy,
              onPressed: _instruction.text.trim().isEmpty ? null : _run,
            ),
          ],
        ],
      ),
    );
  }
}
