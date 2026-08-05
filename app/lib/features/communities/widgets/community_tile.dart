import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/community_models.dart';

class CommunityTile extends StatelessWidget {
  const CommunityTile({
    super.key,
    required this.community,
    required this.onTap,
    required this.onToggle,
  });

  final Community community;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                community.name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: colors.accent,
                  fontSize: AppTypeScale.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: AppTypeScale.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    community.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: AppTypeScale.caption,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            const SizedBox(width: AppSpacing.md),
            _JoinButton(isMember: community.isMember, onTap: onToggle),
          ],
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.isMember, required this.onTap});

  final bool isMember;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: isMember ? Colors.transparent : colors.accent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: isMember ? colors.border : colors.accent),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            isMember ? 'Joined' : 'Join',
            style: TextStyle(
              color: isMember ? colors.textSecondary : colors.accentText,
              fontSize: AppTypeScale.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
