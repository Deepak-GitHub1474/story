class SupportTicket {
  const SupportTicket({
    required this.ticketId,
    required this.type,
    required this.state,
    required this.reason,
    required this.requiredRole,
    required this.createdAt,
    this.resolution,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    ticketId: json['ticket_id'] as String,
    type: json['type'] as String,
    state: json['state'] as String,
    reason: json['reason'] as String? ?? '',
    requiredRole: json['required_role'] as String? ?? 'admin',
    createdAt: json['created_at'] as String? ?? '',
    resolution: json['resolution'] as String?,
  );

  final String ticketId;
  final String type;
  final String state;
  final String reason;
  final String requiredRole;
  final String createdAt;
  final String? resolution;

  bool get isOpen => state != 'closed' && state != 'rejected';

  bool get isReady => state == 'reveal_ready';
}

class SecurityEvent {
  const SecurityEvent({
    required this.action,
    required this.outcome,
    required this.occurredAt,
    this.byRole,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
    action: json['action'] as String,
    outcome: json['outcome'] as String? ?? 'success',
    occurredAt: json['occurred_at'] as String? ?? '',
    byRole: json['by_role'] as String?,
  );

  final String action;
  final String outcome;
  final String occurredAt;
  final String? byRole;
}
