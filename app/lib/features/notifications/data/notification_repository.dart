import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/notification_models.dart';

class NotificationRepository {
  const NotificationRepository(this._client);

  final ApiClient _client;

  Future<Result<List<AppNotification>>> list() => _client.get(
    Endpoints.notifications,
    query: {'limit': 30},
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<int>> unreadCount() => _client.get(
    Endpoints.unreadCount,
    parse: (data) => data['unread'] as int,
  );

  Future<Result<bool>> markRead(String id) => _client.post(
    Endpoints.markNotificationRead(id),
    parse: (data) => data['read'] as bool? ?? true,
  );

  Future<Result<bool>> markAllRead() => _client.post(
    Endpoints.markAllNotificationsRead,
    parse: (data) => data['read'] as bool? ?? true,
  );
}
