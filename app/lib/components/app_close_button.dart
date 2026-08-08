import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum AppCloseSize { small, medium }

class AppCloseButton extends StatelessWidget {
  const AppCloseButton({
    super.key,
    required this.onPressed,
    this.size = AppCloseSize.medium,
    this.tooltip = 'Close',
    this.isOnImage = false,
  });

  final VoidCallback onPressed;
  final AppCloseSize size;
  final String tooltip;
  final bool isOnImage;

  double get _icon => size == AppCloseSize.small ? 18 : 22;

  double get _tap => size == AppCloseSize.small ? 32 : 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final mark = Icon(
      Icons.close_rounded,
      size: _icon,
      weight: 600,
      color: isOnImage ? Colors.white : colors.textSecondary,
    );

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: _tap / 2 + 4,
        child: SizedBox(
          width: _tap,
          height: _tap,
          child: isOnImage
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: mark,
                  ),
                )
              : Center(child: mark),
        ),
      ),
    );
  }
}
