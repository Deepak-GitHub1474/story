import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/result.dart';
import '../models/call_models.dart';

class CallRepository {
  const CallRepository(this._client);

  final ApiClient _client;

  Future<Result<CallStart>> start(String conversationId) => _client.post(
    Endpoints.calls,
    body: {'conversation_id': conversationId},
    parse: CallStart.fromJson,
  );

  Future<Result<CallInvite>> pending(String callId) => _client.get(
    Endpoints.pendingCall(callId),
    parse: CallInvite.fromJson,
  );

  Future<Result<CallHistoryPage>> history({String? cursor, int limit = 30}) =>
      _client.get(
        Endpoints.calls,
        query: {'limit': limit, 'cursor': ?cursor},
        parse: CallHistoryPage.fromJson,
      );

  Future<Result<int>> deleteOne(String callId) => _client.delete(
    Endpoints.call(callId),
    parse: (data) => data['deleted'] as int? ?? 0,
  );

  Future<Result<int>> deleteMany(List<String> callIds) => _client.post(
    Endpoints.callsDelete,
    body: {'call_ids': callIds},
    parse: (data) => data['deleted'] as int? ?? 0,
  );

  Future<Result<int>> deleteAll() => _client.post(
    Endpoints.callsDelete,
    body: {'all': true},
    parse: (data) => data['deleted'] as int? ?? 0,
  );

  Future<Result<int>> setRetention(int days) => _client.put(
    Endpoints.callRetention,
    body: {'days': days},
    parse: (data) => data['call_history_days'] as int? ?? days,
  );
}
