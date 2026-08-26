import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/call_models.dart';

class CallTile extends StatelessWidget {
  const CallTile({
    required this.record,
    required this.name,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
    required this.onCall,
    super.key,
  });

  final CallRecord record;
  final String name;
  final bool isSelected;
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCall;

  IconData get _icon => switch (record.direction) {
    CallDirection.incoming =>
      record.wasAnswered ? Icons.call_received : Icons.call_missed,
    CallDirection.outgoing =>
      record.wasAnswered ? Icons.call_made : Icons.call_missed_outgoing,
  };

  String get _line {
    final spoken = record.spoken;
    final when = TimeOfDay.fromDateTime(record.startedAt).format24();
    return switch (record.outcome) {
      CallOutcome.answered => '$when · $spoken',
      CallOutcome.missed => '$when · Missed',
      CallOutcome.declined => '$when · Declined',
      CallOutcome.busy => '$when · Busy',
      CallOutcome.failed => '$when · Did not connect',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final missed = !record.wasAnswered;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (isSelecting) ...[
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? colors.accent : colors.textMuted,
                size: AppSizes.iconMd,
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            AppAvatar(
              seed: record.peer?.avatarSeed ?? record.peerId,
              size: 44,
              displayName: name,
              username: record.peer?.username,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: missed ? colors.like : colors.textPrimary,
                      fontSize: AppTypeScale.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_icon, size: AppSizes.iconSm, color: colors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _line,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: AppTypeScale.label,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isSelecting)
              IconButton(
                tooltip: 'Call back',
                icon: Icon(Icons.call, color: colors.accent),
                onPressed: onCall,
              ),
          ],
        ),
      ),
    );
  }
}

extension on TimeOfDay {
  String format24() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
