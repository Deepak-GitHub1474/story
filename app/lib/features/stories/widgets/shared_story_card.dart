import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';

class SharedStoryCard extends StatelessWidget {
  const SharedStoryCard({super.key, required this.shared, this.onTap});

  final SharedStory shared;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border, width: AppSizes.hairline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  seed: shared.author.avatarSeed,
                  size: 22,
                  displayName: shared.author.handle,
                  username: shared.author.username,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    shared.author.handle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: AppTypeScale.caption,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (shared.title != null && shared.title!.isNotEmpty) ...[
              Text(
                shared.title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.label,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              shared.excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: AppTypeScale.label,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
