import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/endpoints.dart';

typedef RealtimeEvent = Map<String, dynamic>;

class RealtimeClient {
  RealtimeClient(this._token);

  final Future<String?> Function() _token;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _listener;
  Timer? _retry;
  int _attempt = 0;
  bool _closed = false;

  final _events = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<void> connect() async {
    if (_closed || isConnected) return;

    final token = await _token();
    if (token == null) return;

    try {
      final url = Endpoints.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final socket = await WebSocket.connect('$url/ws?token=$token');
      if (_closed) {
        await socket.close();
        return;
      }

      _socket = socket;
      _attempt = 0;
      _listener = socket.listen(
        (raw) {
          try {
            final decoded = jsonDecode(raw as String);
            if (decoded is Map) _events.add(Map<String, dynamic>.from(decoded));
          } catch (_) {}
        },
        onDone: _scheduleRetry,
        onError: (_) => _scheduleRetry(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _socket = null;
    if (_closed) return;

    _attempt = (_attempt + 1).clamp(1, 6);
    final seconds = [1, 2, 4, 8, 15, 30][_attempt - 1];
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), connect);
  }

  Future<void> dispose() async {
    _closed = true;
    _retry?.cancel();
    await _listener?.cancel();
    await _socket?.close();
    await _events.close();
  }
}
