import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/recovery_models.dart';

class RecoveryRepository {
  const RecoveryRepository(this._client);

  final ApiClient _client;

  Future<Result<SupportTicket>> open({
    required String type,
    required String reason,
  }) => _client.post(
    Endpoints.tickets,
    body: {'type': type, 'reason': reason},
    parse: (data) =>
        SupportTicket.fromJson(Map<String, dynamic>.from(data['ticket'] as Map)),
  );

  Future<Result<List<SupportTicket>>> tickets() => _client.get(
    Endpoints.tickets,
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => SupportTicket.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );

  Future<Result<List<SecurityEvent>>> securityActivity() => _client.get(
    Endpoints.securityActivity,
    parse: (data) => (data['items'] as List<dynamic>)
        .map((item) => SecurityEvent.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );
}
