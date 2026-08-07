import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../result.dart';
import '../storage/secure_store.dart';
import 'endpoints.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({required SecureStore store, Dio? dio, this.onSessionExpired})
    : _store = store,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Endpoints.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'content-type': 'application/json'},
              validateStatus: (_) => true,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _store.readAccessToken();
            if (token != null) {
              options.headers['authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStore _store;
  final Future<void> Function()? onSessionExpired;

  Completer<bool>? _refreshInFlight;

  Future<Result<T>> get<T>(
    String path, {
    JsonMap? query,
    required T Function(JsonMap data) parse,
    bool skipAuth = false,
  }) => _send(
    () => _dio.get(
      path,
      queryParameters: query,
      options: Options(extra: {'skipAuth': skipAuth}),
    ),
    parse,
    skipAuth: skipAuth,
  );

  Future<Result<T>> patch<T>(
    String path, {
    JsonMap? body,
    required T Function(JsonMap data) parse,
    bool skipAuth = false,
  }) => _send(
    () => _dio.patch(path, data: body, options: Options(extra: {'skipAuth': skipAuth})),
    parse,
    skipAuth: skipAuth,
  );

  Future<Result<T>> put<T>(
    String path, {
    JsonMap? body,
    required T Function(JsonMap data) parse,
    bool skipAuth = false,
  }) => _send(
    () => _dio.put(path, data: body, options: Options(extra: {'skipAuth': skipAuth})),
    parse,
    skipAuth: skipAuth,
  );

  Future<Result<T>> delete<T>(
    String path, {
    JsonMap? body,
    required T Function(JsonMap data) parse,
    bool skipAuth = false,
  }) => _send(
    () => _dio.delete(path, data: body, options: Options(extra: {'skipAuth': skipAuth})),
    parse,
    skipAuth: skipAuth,
  );

  Future<Result<T>> post<T>(
    String path, {
    JsonMap? body,
    required T Function(JsonMap data) parse,
    bool skipAuth = false,
  }) => _send(
    () => _dio.post(path, data: body, options: Options(extra: {'skipAuth': skipAuth})),
    parse,
    skipAuth: skipAuth,
  );

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(JsonMap data) parse, {
    required bool skipAuth,
    bool retried = false,
  }) async {
    late Response<dynamic> response;
    try {
      response = await request();
    } on SocketException {
      return const Failure(
        code: 'NETWORK_UNAVAILABLE',
        message: 'No connection. Check your network and try again.',
      );
    } on DioException catch (error) {
      if (error.response == null) {
        return const Failure(
          code: 'NETWORK_UNAVAILABLE',
          message: 'No connection. Check your network and try again.',
        );
      }
      response = error.response!;
    }

    final body = response.data;
    if (body is! Map) {
      return Failure(
        code: 'MALFORMED_RESPONSE',
        message: 'The server returned something unexpected.',
        statusCode: response.statusCode,
      );
    }

    final envelope = Map<String, dynamic>.from(body);
    final success = envelope['success'] == true;
    final message = envelope['message'] as String? ?? '';
    final data = envelope['data'];

    if (success && (response.statusCode ?? 500) < 400) {
      final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      return Success(parse(payload), message: message);
    }

    final errorData = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final code = errorData['code'] as String? ?? 'INTERNAL_ERROR';

    final isExpired = response.statusCode == 401 && code == 'TOKEN_EXPIRED';
    if (isExpired && !skipAuth && !retried) {
      final refreshed = await _refreshOnce();
      if (refreshed) {
        return _send(request, parse, skipAuth: skipAuth, retried: true);
      }
      await onSessionExpired?.call();
    } else if (response.statusCode == 401 && !skipAuth) {
      await onSessionExpired?.call();
    }

    return Failure(
      code: code,
      message: message.isEmpty ? 'Something went wrong.' : message,
      field: errorData['field'] as String?,
      fields: (errorData['fields'] as List<dynamic>? ?? [])
          .map((item) => FieldError.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      statusCode: response.statusCode,
      details: errorData,
    );
  }

  Future<bool> _refreshOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshInFlight = completer;

    unawaited(
      _performRefresh().then((value) {
        _refreshInFlight = null;
        completer.complete(value);
      }),
    );

    return completer.future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null) return false;

    final response = await _dio.post(
      Endpoints.refresh,
      data: {'refresh_token': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );

    final body = response.data;
    if (body is! Map || body['success'] != true) {
      await _store.clear();
      return false;
    }

    final tokens = Map<String, dynamic>.from(
      (body['data'] as Map)['tokens'] as Map,
    );
    await _store.saveTokens(
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
    return true;
  }
}
