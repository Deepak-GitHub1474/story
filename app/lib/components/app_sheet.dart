import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

typedef AppSheetShell = Widget Function(BuildContext, ScrollController);

Future<T?> showAppSheet<T>({
  required BuildContext context,
  WidgetBuilder? builder,
  AppSheetShell? shell,
  String? title,
  bool isScrollControlled = true,
  EdgeInsets contentPadding = AppSheet.insets,
  Widget? footer,
  bool isResizable = false,
  double initialSize = 0.68,
  double minSize = 0.45,
  double maxSize = 1,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useRootNavigator: true,
  useSafeArea: isResizable || shell != null,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => isResizable || shell != null
      ? DraggableScrollableSheet(
          initialChildSize: initialSize,
          minChildSize: minSize,
          maxChildSize: maxSize,
          expand: false,
          shouldCloseOnMinExtent: true,
          builder: (context, scrollController) =>
              shell?.call(sheetContext, scrollController) ??
              AppSheet(
                title: title,
                contentPadding: contentPadding,
                footer: footer,
                scrollController: scrollController,
                child: builder!(sheetContext),
              ),
        )
      : AppSheet(
          title: title,
          contentPadding: contentPadding,
          footer: footer,
          child: builder!(sheetContext),
        ),
);

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    this.child,
    this.body,
    this.title,
    this.contentPadding = insets,
    this.footer,
    this.scrollController,
  }) : assert(child != null || body != null, 'a sheet needs something to show');

  static const EdgeInsets insets = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.md,
    AppSpacing.lg,
    0,
  );

  final Widget? child;
  final Widget? body;
  final String? title;
  final EdgeInsets contentPadding;
  final Widget? footer;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final isResizable = scrollController != null || body != null;

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
        border: Border(
          top: BorderSide(color: colors.border, width: AppSizes.hairline),
        ),
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
            child: ListTileTheme.merge(
              contentPadding: EdgeInsets.zero,
              child:
                  body ??
                  SingleChildScrollView(
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
