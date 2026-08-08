import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/app_avatar.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/community_models.dart';
import '../providers/community_providers.dart';

class SuggestionsStrip extends ConsumerWidget {
  const SuggestionsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(suggestionsProvider);

    return suggestions.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.communities.isNotEmpty) ...[
              const _Heading('Rooms that fit what you follow'),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: data.communities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) => _RoomCard(
                    community: data.communities[index],
                    onTap: () => context.push(
                      '${Routes.community}/${data.communities[index].slug}',
                    ),
                  ),
                ),
              ),
            ],
            if (data.people.isNotEmpty) ...[
              const _Heading('People writing near you'),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: data.people.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) => _PersonCard(
                    person: data.people[index],
                    onTap: () {
                      final username = data.people[index].username;
                      if (username != null) {
                        context.push('${Routes.user}/$username');
                      }
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: AppTypeScale.caption,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.community, required this.onTap});

  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 208,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              community.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: Text(
                community.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTypeScale.caption,
                  height: 1.5,
                ),
              ),
            ),
            Text(
              '${community.members} ${community.members == 1 ? 'member' : 'members'}',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: AppTypeScale.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onTap});

  final SuggestedPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 152,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppAvatar(
              seed: person.avatarSeed,
              size: 40,
              displayName: person.displayName,
              username: person.username,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              person.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.label,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                person.reason,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: AppTypeScale.caption,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
