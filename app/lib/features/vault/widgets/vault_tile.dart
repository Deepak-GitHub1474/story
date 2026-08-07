import 'package:flutter/material.dart';

import '../../../components/app_card.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/vault_models.dart';

class VaultTile extends StatelessWidget {
  const VaultTile({
    super.key,
    required this.item,
    this.isHiddenResult = false,
    this.onTap,
    this.onRemove,
  });

  final VaultItem item;
  final bool isHiddenResult;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  IconData get _icon => switch (item.kind) {
    'image' => Icons.image_outlined,
    'video' => Icons.videocam_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final megabytes = item.sizeBytes / 1048576;

    return InkWell(
      onTap: onTap,
      onLongPress: onRemove,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_icon, color: colors.accent, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encrypted ${item.kind}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: AppTypeScale.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${megabytes.toStringAsFixed(1)} MB · ${item.chunkCount} chunks',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ],
            ),
          ),
          if (isHiddenResult)
            Icon(Icons.visibility_off_outlined, size: AppSizes.iconSm, color: colors.accent)
          else if (item.isOrphaned)
            Icon(Icons.key_off_outlined, size: AppSizes.iconSm, color: colors.danger)
          else if (!item.isReady)
            SizedBox(
              width: AppSizes.iconSm,
              height: AppSizes.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.textMuted),
            ),
        ],
      ),
      ),
    );
  }
}
