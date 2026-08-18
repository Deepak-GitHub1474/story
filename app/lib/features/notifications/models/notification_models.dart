class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.kind,
    required this.actorName,
    required this.actorAvatarSeed,
    required this.actorUsername,
    required this.targetKind,
    required this.targetId,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = Map<String, dynamic>.from(json['actor'] as Map? ?? {});
    final target = Map<String, dynamic>.from(json['target'] as Map? ?? {});
    return AppNotification(
      notificationId: json['notification_id'] as String,
      kind: json['kind'] as String,
      actorName: actor['display_name'] as String? ?? 'Someone',
      actorAvatarSeed: actor['avatar_seed'] as String? ?? '',
      actorUsername: actor['username'] as String? ?? '',
      targetKind: target['kind'] as String? ?? '',
      targetId: target['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final String notificationId;
  final String kind;
  final String actorName;
  final String actorAvatarSeed;
  final String actorUsername;
  final String targetKind;
  final String targetId;
  final String body;
  final bool isRead;
  final String createdAt;

  AppNotification asRead() => AppNotification(
    notificationId: notificationId,
    kind: kind,
    actorName: actorName,
    actorAvatarSeed: actorAvatarSeed,
    actorUsername: actorUsername,
    targetKind: targetKind,
    targetId: targetId,
    body: body,
    isRead: true,
    createdAt: createdAt,
  );
}
