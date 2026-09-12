import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/call_models.dart';

class CallEvent extends StatelessWidget {
  const CallEvent({required this.record, super.key});

  final CallRecord record;

  IconData get _icon => switch (record.direction) {
    CallDirection.incoming =>
      record.wasAnswered ? Icons.call_received : Icons.call_missed,
    CallDirection.outgoing =>
      record.wasAnswered ? Icons.call_made : Icons.call_missed_outgoing,
  };

  String get _label {
    final outgoing = record.direction == CallDirection.outgoing;
    return switch (record.outcome) {
      CallOutcome.answered => outgoing ? 'Outgoing call' : 'Incoming call',
      CallOutcome.missed => outgoing ? 'No answer' : 'Missed call',
      CallOutcome.declined => outgoing ? 'Declined' : 'You declined',
      CallOutcome.busy => 'On another call',
      CallOutcome.failed => 'Call did not connect',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final missed = !record.wasAnswered;
    final tint = missed ? colors.like : colors.textSecondary;
    final spoken = record.spoken;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: AppSizes.iconSm, color: tint),
            const SizedBox(width: AppSpacing.xs),
            Text(
              spoken == null ? _label : '$_label · $spoken',
              style: TextStyle(color: tint, fontSize: AppTypeScale.caption),
            ),
          ],
        ),
      ),
    );
  }
}
