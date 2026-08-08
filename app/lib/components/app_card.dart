import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.isDanger = false,
    this.icon,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelColor = isDanger ? colors.danger : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconMd, color: labelColor),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: labelColor, fontSize: AppTypeScale.body),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: AppTypeScale.body,
                ),
              ),
            ?trailing,
            if (onTap != null && trailing == null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconMd,
                  color: colors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
            top: AppSpacing.xl,
          ),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: AppTypeScale.caption,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  Divider(height: 1, thickness: 1, color: colors.border, indent: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
