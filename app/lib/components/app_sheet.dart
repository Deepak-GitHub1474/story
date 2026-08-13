import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,
  EdgeInsets contentPadding = const EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.md,
    AppSpacing.lg,
    0,
  ),
  Widget? footer,
  bool isResizable = false,
  double initialSize = 0.68,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useRootNavigator: true,
  useSafeArea: isResizable,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => isResizable
      ? DraggableScrollableSheet(
          initialChildSize: initialSize,
          minChildSize: 0.45,
          maxChildSize: 1,
          expand: false,
          shouldCloseOnMinExtent: true,
          builder: (context, scrollController) => AppSheet(
            title: title,
            contentPadding: contentPadding,
            footer: footer,
            scrollController: scrollController,
            child: builder(sheetContext),
          ),
        )
      : AppSheet(
          title: title,
          contentPadding: contentPadding,
          footer: footer,
          child: builder(sheetContext),
        ),
);

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.title,
    this.contentPadding = EdgeInsets.zero,
    this.footer,
    this.scrollController,
  });

  final Widget child;
  final String? title;
  final EdgeInsets contentPadding;
  final Widget? footer;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final isResizable = scrollController != null;

    return Container(
      constraints: isResizable
          ? null
          : BoxConstraints(
              minHeight: media.size.height * 0.28,
              maxHeight: media.size.height * 0.88,
            ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: isResizable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                title!,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: AppTypeScale.heading,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: colors.border.withValues(alpha: 0.45),
            ),
          ],
          Flexible(
            child: SingleChildScrollView(
              controller: scrollController,
              physics: isResizable
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
              padding: contentPadding.copyWith(
                bottom: footer != null
                    ? AppSpacing.lg
                    : media.viewInsets.bottom +
                          media.padding.bottom +
                          AppSpacing.lg,
              ),
              child: child,
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom:
                    media.viewInsets.bottom +
                    media.padding.bottom +
                    AppSpacing.lg,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}
