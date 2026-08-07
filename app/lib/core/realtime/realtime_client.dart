import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/endpoints.dart';

typedef RealtimeEvent = Map<String, dynamic>;

class RealtimeClient {
  RealtimeClient(this._ticket);

  final Future<String?> Function() _ticket;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _listener;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _closed = false;

  final _events = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<void> connect() async {
    if (_closed || isConnected) return;

    final ticket = await _ticket();
    if (ticket == null) {
      _scheduleRetry();
      return;
    }

    try {
      final url = Endpoints.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final socket = await WebSocket.connect('$url/ws?ticket=$ticket');
      if (_closed) {
        await socket.close();
        return;
      }

      _socket = socket;
      _attempt = 0;
      _startPing();
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

  void send(Map<String, dynamic> event) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode(event));
  }

  void _startPing() {
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 45), (_) {
      final socket = _socket;
      if (socket == null || socket.readyState != WebSocket.open) return;
      socket.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _scheduleRetry() {
    _ping?.cancel();
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
    _ping?.cancel();
    await _listener?.cancel();
    await _socket?.close();
    await _events.close();
  }
}
