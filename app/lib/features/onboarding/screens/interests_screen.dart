import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_button.dart';
import '../../../components/app_scaffold.dart';
import '../../../components/app_toast.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  late final Set<String> _selected = {...(ref.read(authProvider).user?.interests ?? const [])};
  bool _isSaving = false;

  static const _maxInterests = 12;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final result = await ref
        .read(profileRepositoryProvider)
        .updateProfile(interests: _selected.toList());

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      AppToast.show(context, 'Interests saved.', kind: AppToastKind.success);
      if (widget.isOnboarding) {
        context.go(Routes.stories);
      } else {
        context.pop();
      }
    } else {
      AppToast.show(context, result.failureOrNull!.message, kind: AppToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interests = ref.watch(interestsProvider);

    return AppScaffold(
      title: 'What are you carrying?',
      leading: widget.isOnboarding
          ? null
          : BackButton(onPressed: () => context.pop()),
      actions: widget.isOnboarding
          ? [
              TextButton(
                onPressed: () => context.go(Routes.stories),
                child: Text('Skip', style: TextStyle(color: colors.textMuted)),
              ),
            ]
          : null,
      child: interests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Could not load interests.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        data: (options) {
          final byCategory = <String, List<dynamic>>{};
          for (final option in options) {
            byCategory.putIfAbsent(option.categoryId, () => []).add(option);
          }

          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick up to $_maxInterests. This shapes what you are shown, and '
                  'nobody else can see your choices.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AppTypeScale.body,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in byCategory.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                          bottom: AppSpacing.sm,
                        ),
                        child: Text(
                          entry.key.replaceAll('-', ' ').toUpperCase(),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: AppTypeScale.caption,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final option in entry.value)
                            _InterestChip(
                              label: option.name as String,
                              isSelected: _selected.contains(option.slug),
                              onTap: () => setState(() {
                                if (_selected.contains(option.slug)) {
                                  _selected.remove(option.slug);
                                } else if (_selected.length < _maxInterests) {
                                  _selected.add(option.slug as String);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              AppButton(
                label: _selected.isEmpty
                    ? 'Skip for now'
                    : 'Save ${_selected.length} selected',
                isLoading: _isSaving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedScale(
      scale: isSelected ? 1.04 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: Material(
        color: isSelected ? colors.accent : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? colors.accent : colors.border,
              ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.accentText : colors.textSecondary,
                fontSize: AppTypeScale.label,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
