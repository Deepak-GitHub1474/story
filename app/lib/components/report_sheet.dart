import 'package:flutter/material.dart';

import 'app_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/endpoints.dart';
import '../features/auth/providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_toast.dart';

class ReportReason {
  const ReportReason(this.value, this.label, this.detail);

  final String value;
  final String label;
  final String detail;
}

const reportReasons = [
  ReportReason('harassment', 'Harassment', 'Targeting or attacking someone.'),
  ReportReason('spam', 'Spam', 'Promotion, repetition, or link farming.'),
  ReportReason('self_harm', 'Someone at risk', 'This person may be in danger.'),
  ReportReason('illegal', 'Illegal', 'Illegal goods, services, or content.'),
  ReportReason('impersonation', 'Impersonation', 'Pretending to be a real person.'),
  ReportReason('wrong_community', 'Wrong room', 'Does not belong in this community.'),
  ReportReason('other', 'Something else', 'Tell us in your own words.'),
];

Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetKind,
  required String targetId,
}) async {
  final colors = context.colors;

  final reason = await showAppSheet<ReportReason>(
    context: context,
    title: 'Report',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'A person reads every report. The author is never told who sent it.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: AppTypeScale.caption,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final option in reportReasons)
          ListTile(
            title: Text(
              option.label,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              option.detail,
              style: TextStyle(color: colors.textMuted, fontSize: AppTypeScale.caption),
            ),
            onTap: () => Navigator.of(sheetContext).pop(option),
          ),
      ],
    ),
  );

  if (reason == null || !context.mounted) return;

  final result = await ref.read(apiClientProvider).post<bool>(
    Endpoints.reports,
    body: {
      'target_kind': targetKind,
      'target_id': targetId,
      'reason': reason.value,
    },
    parse: (data) => data['reported'] as bool? ?? true,
  );

  if (!context.mounted) return;
  AppToast.show(
    context,
    result.isSuccess
        ? 'Reported. Thank you for telling us.'
        : result.failureOrNull!.message,
    kind: result.isSuccess ? AppToastKind.success : AppToastKind.error,
  );
}
