import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/skeleton.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/community_providers.dart';
import '../widgets/community_tile.dart';
import '../widgets/suggestions_strip.dart';

class CommunitiesScreen extends ConsumerWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final categories = ref.watch(categoriesProvider);
    final browse = ref.watch(communityBrowseProvider);
    final selected = ref.watch(communityBrowseProvider.notifier).category;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Communities'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SizedBox(
              height: 44,
              child: categories.when(
                loading: () => const SizedBox.shrink(),
                error: (error, _) => const SizedBox.shrink(),
                data: (items) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      isActive: selected == null,
                      onTap: () =>
                          ref.read(communityBrowseProvider.notifier).filter(null),
                    ),
                    for (final category in items)
                      _CategoryChip(
                        label: category.name,
                        isActive: selected == category.slug,
                        onTap: () => ref
                            .read(communityBrowseProvider.notifier)
                            .filter(category.slug),
                      ),
                  ],
                ),
              ),
              ),
            ),
            Expanded(
              child: browse.when(
                loading: () => const SkeletonList(count: 5),
                error: (error, _) => Center(
                  child: Text(
                    'Could not load communities.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                data: (items) => RefreshIndicator(
                  color: colors.accent,
                  backgroundColor: colors.surface,
                  onRefresh: () async {
                    ref.invalidate(suggestionsProvider);
                    await ref.read(communityBrowseProvider.notifier).load();
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                    itemCount: items.length + 1,
                    separatorBuilder: (context, index) => index == 0
                        ? const SizedBox.shrink()
                        : Divider(height: 1, color: colors.border),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return selected == null
                            ? const SuggestionsStrip()
                            : const SizedBox.shrink();
                      }

                      final community = items[index - 1];
                      return CommunityTile(
                        community: community,
                        onTap: () =>
                            context.push('${Routes.community}/${community.slug}'),
                        onToggle: () => ref
                            .read(communityBrowseProvider.notifier)
                            .toggleMembership(community),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.xs),
      child: Material(
        color: isActive ? colors.accent : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: isActive ? colors.accent : colors.border),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? colors.accentText : colors.textSecondary,
                fontSize: AppTypeScale.label,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
