import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';
import 'package:story_app/features/calls/data/call_repository.dart';
import 'package:story_app/features/calls/models/call_models.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'Fine.',
        'data': handler(options),
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class InMemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

({CallRepository repository, StubAdapter adapter}) build(
  Map<String, dynamic> Function(RequestOptions options) handler,
) {
  final adapter = StubAdapter(handler);
  final dio = Dio(
    BaseOptions(baseUrl: 'http://test/v1', validateStatus: (_) => true),
  )..httpClientAdapter = adapter;
  return (
    repository: CallRepository(
      ApiClient(store: SecureStore(InMemoryStore()), dio: dio),
    ),
    adapter: adapter,
  );
}

final startPayload = {
  'call_id': 'cal_1',
  'conversation_id': 'cnv_1',
  'media': ['audio'],
  'peer': {'user_id': 'usr_2', 'username': 'bo', 'display_name': 'bo'},
  'ice_servers': [
    {'urls': ['stun:stun.example.org:19302']},
  ],
  'ring_timeout_seconds': 45,
};

void main() {
  test('starting a call posts the conversation to /calls', () async {
    final built = build((_) => startPayload);

    final result = await built.repository.start('cnv_1');

    final request = built.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/calls');
    expect(request.data, {'conversation_id': 'cnv_1'});
    expect(result.valueOrNull, isA<CallStart>());
    expect(result.valueOrNull!.callId, 'cal_1');
  });

  test('history asks for a page and passes the cursor on', () async {
    final built = build((_) => {'items': [], 'next_cursor': null, 'has_more': false});

    await built.repository.history(cursor: 'abc|chi_1', limit: 10);

    final request = built.adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/calls');
    expect(request.queryParameters, {'limit': 10, 'cursor': 'abc|chi_1'});
  });

  test('the first page sends no cursor', () async {
    final built = build((_) => {'items': [], 'next_cursor': null, 'has_more': false});

    await built.repository.history();

    expect(built.adapter.requests.single.queryParameters, {'limit': 30});
  });

  test('deleting one call hits its own path', () async {
    final built = build((_) => {'deleted': 1});

    final result = await built.repository.deleteOne('cal_1');

    expect(built.adapter.requests.single.method, 'DELETE');
    expect(built.adapter.requests.single.path, '/calls/cal_1');
    expect(result.valueOrNull, 1);
  });

  test('deleting a selection posts the ids', () async {
    final built = build((_) => {'deleted': 2});

    final result = await built.repository.deleteMany(['cal_1', 'cal_2']);

    final request = built.adapter.requests.single;
    expect(request.path, '/calls/delete');
    expect(request.data, {'call_ids': ['cal_1', 'cal_2']});
    expect(result.valueOrNull, 2);
  });

  test('clearing everything sends all, not a list', () async {
    final built = build((_) => {'deleted': 9});

    await built.repository.deleteAll();

    expect(built.adapter.requests.single.data, {'all': true});
  });

  test('retention is a put carrying days', () async {
    final built = build((_) => {'call_history_days': 7, 'restamped': 3});

    final result = await built.repository.setRetention(7);

    final request = built.adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/calls/retention');
    expect(request.data, {'days': 7});
    expect(result.valueOrNull, 7);
  });

  test('keep forever is zero days, not a missing field', () async {
    final built = build((_) => {'call_history_days': 0, 'restamped': 3});

    await built.repository.setRetention(0);

    expect(built.adapter.requests.single.data, {'days': 0});
  });
}
