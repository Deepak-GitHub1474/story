import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/api/api_client.dart';
import 'package:story_app/core/storage/secure_store.dart';

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _encode(Map<String, dynamic> body) {
  final buffer = StringBuffer('{');
  final entries = body.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    buffer.write('"${entries[i].key}":${_encodeValue(entries[i].value)}');
    if (i < entries.length - 1) buffer.write(',');
  }
  buffer.write('}');
  return buffer.toString();
}

String _encodeValue(Object? value) => switch (value) {
  null => 'null',
  bool() => value.toString(),
  num() => value.toString(),
  String() => '"$value"',
  Map<String, dynamic>() => _encode(value),
  List() => '[${value.map(_encodeValue).join(',')}]',
  _ => '"$value"',
};

ApiClient buildClient(StubAdapter adapter, SecureStore store) {
  final dio = Dio(
    BaseOptions(baseUrl: 'http://test/v1', validateStatus: (_) => true),
  )..httpClientAdapter = adapter;
  return ApiClient(store: store, dio: dio);
}

void main() {
  late SecureStore store;

  setUp(() {
    store = SecureStore(InMemoryStore());
  });

  test('unwraps a success envelope into Success', () async {
    final adapter = StubAdapter(
      (_) async => json({
        'success': true,
        'message': 'Loaded.',
        'data': {'value': 42},
      }, 200),
    );

    final result = await buildClient(adapter, store).get<int>(
      '/thing',
      parse: (data) => data['value'] as int,
    );

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, 42);
  });

  test('unwraps an error envelope into Failure with its code', () async {
    final adapter = StubAdapter(
      (_) async => json({
        'success': false,
        'message': 'That username is already taken.',
        'data': {'code': 'USERNAME_TAKEN', 'field': 'username'},
      }, 409),
    );

    final result = await buildClient(adapter, store).post<int>(
      '/thing',
      parse: (data) => 0,
    );

    final failure = result.failureOrNull!;
    expect(failure.code, 'USERNAME_TAKEN');
    expect(failure.field, 'username');
    expect(failure.statusCode, 409);
  });

  test('carries validation field errors through', () async {
    final adapter = StubAdapter(
      (_) async => json({
        'success': false,
        'message': 'This field is required.',
        'data': {
          'code': 'VALIDATION_FAILED',
          'field': 'username',
          'fields': [
            {
              'field': 'username',
              'code': 'MISSING',
              'message': 'This field is required.',
            },
          ],
        },
      }, 422),
    );

    final result = await buildClient(adapter, store).post<int>(
      '/thing',
      parse: (data) => 0,
    );

    expect(result.failureOrNull!.fields.single.field, 'username');
  });

  test('attaches the stored access token', () async {
    await store.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
    final adapter = StubAdapter(
      (_) async => json({'success': true, 'message': 'Ok.', 'data': {}}, 200),
    );

    await buildClient(adapter, store).get<int>('/thing', parse: (_) => 0);

    expect(adapter.requests.single.headers['authorization'], 'Bearer access-1');
  });

  test('omits the token when the call opts out of auth', () async {
    await store.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
    final adapter = StubAdapter(
      (_) async => json({'success': true, 'message': 'Ok.', 'data': {}}, 200),
    );

    await buildClient(
      adapter,
      store,
    ).post<int>('/auth/signin', parse: (_) => 0, skipAuth: true);

    expect(adapter.requests.single.headers.containsKey('authorization'), isFalse);
  });

  test('refreshes once on TOKEN_EXPIRED and retries the original call', () async {
    await store.saveTokens(accessToken: 'stale', refreshToken: 'refresh-1');
    var protectedCalls = 0;

    final adapter = StubAdapter((options) async {
      if (options.path == '/auth/refresh') {
        return json({
          'success': true,
          'message': 'Refreshed.',
          'data': {
            'tokens': {
              'access_token': 'fresh',
              'refresh_token': 'refresh-2',
            },
          },
        }, 200);
      }
      protectedCalls++;
      if (protectedCalls == 1) {
        return json({
          'success': false,
          'message': 'Your session expired. Sign in again.',
          'data': {'code': 'TOKEN_EXPIRED'},
        }, 401);
      }
      return json({
        'success': true,
        'message': 'Ok.',
        'data': {'value': 7},
      }, 200);
    });

    final result = await buildClient(
      adapter,
      store,
    ).get<int>('/thing', parse: (data) => data['value'] as int);

    expect(result.valueOrNull, 7);
    expect(protectedCalls, 2);
    expect(await store.readAccessToken(), 'fresh');
    expect(await store.readRefreshToken(), 'refresh-2');
  });

  test('does not retry forever when the refresh itself fails', () async {
    await store.saveTokens(accessToken: 'stale', refreshToken: 'refresh-1');
    var protectedCalls = 0;

    final adapter = StubAdapter((options) async {
      if (options.path == '/auth/refresh') {
        return json({
          'success': false,
          'message': 'Your session is not valid. Sign in again.',
          'data': {'code': 'TOKEN_INVALID'},
        }, 401);
      }
      protectedCalls++;
      return json({
        'success': false,
        'message': 'Your session expired. Sign in again.',
        'data': {'code': 'TOKEN_EXPIRED'},
      }, 401);
    });

    final result = await buildClient(adapter, store).get<int>(
      '/thing',
      parse: (_) => 0,
    );

    expect(result.failureOrNull!.code, 'TOKEN_EXPIRED');
    expect(protectedCalls, 1);
    expect(await store.readAccessToken(), isNull);
  });

  test('maps a non-envelope body to MALFORMED_RESPONSE', () async {
    final adapter = StubAdapter(
      (_) async => ResponseBody.fromString('<html>gateway error</html>', 502),
    );

    final result = await buildClient(adapter, store).get<int>(
      '/thing',
      parse: (_) => 0,
    );

    expect(result.failureOrNull!.code, 'MALFORMED_RESPONSE');
  });

  test('maps a transport failure to NETWORK_UNAVAILABLE', () async {
    final adapter = StubAdapter(
      (options) => throw DioException(requestOptions: options),
    );

    final result = await buildClient(adapter, store).get<int>(
      '/thing',
      parse: (_) => 0,
    );

    expect(result.failureOrNull!.code, 'NETWORK_UNAVAILABLE');
  });
}
