import 'dart:async';

import '../models/call_models.dart';

abstract class CallMedia {
  Future<void> start({
    required List<Map<String, dynamic>> iceServers,
    required bool asCaller,
  });

  Future<String> createOffer();

  Future<String> createAnswer();

  Future<void> acceptRemote(String sdp);

  Future<void> addCandidate(Map<String, dynamic> candidate);

  Future<void> setMuted(bool value);

  Future<void> setSpeaker(bool value);

  Future<void> stop();
}

abstract class CallSignal {
  void send(Map<String, dynamic> event);
}

class CallSession {
  CallSession({required CallMedia media, required CallSignal signal})
    : _media = media,
      _signal = signal;

  final CallMedia _media;
  final CallSignal _signal;

  CallStart? _start;
  String? _pendingOffer;
  Timer? _ring;

  CallPhase phase = CallPhase.idle;
  DateTime? connectedAt;
  String? endReason;
  bool endedByMe = false;
  bool wasAnswered = false;
  bool isMuted = false;
  bool isSpeakerOn = false;
  List<String> peerMedia = const ['audio'];

  void Function()? onChanged;

  CallStart? get start => _start;

  String? get callId => _start?.callId;

  CallPeer? get peer => _start?.peer;

  bool get isOver => phase == CallPhase.ended;

  bool get isIncoming => _pendingOffer != null;

  void _moveTo(CallPhase next) {
    phase = next;
    onChanged?.call();
  }

  Future<void> place(CallStart start) async {
    _start = start;
    _moveTo(CallPhase.dialling);

    await _media.start(iceServers: start.iceServerMaps, asCaller: true);
    final offer = await _media.createOffer();

    _signal.send({
      'type': 'call.offer',
      'call_id': start.callId,
      'conversation_id': start.conversationId,
      'media': start.media,
      'sdp': offer,
    });

    _startRingTimer(start.ringTimeoutSeconds);
    _moveTo(CallPhase.ringing);
  }

  Future<void> receive(CallStart start, {required String offer}) async {
    _start = start;
    _pendingOffer = offer;
    _startRingTimer(start.ringTimeoutSeconds);
    _moveTo(CallPhase.ringing);
  }

  void _startRingTimer(int seconds) {
    _ring?.cancel();
    _ring = Timer(Duration(seconds: seconds), () {
      if (phase == CallPhase.ringing || phase == CallPhase.dialling) {
        unawaited(_end('timeout', tell: true));
      }
    });
  }

  Future<void> accept() async {
    if (phase != CallPhase.ringing) return;

    final start = _start;
    final offer = _pendingOffer;
    if (start == null || offer == null) return;

    _pendingOffer = null;

    await _media.start(iceServers: start.iceServerMaps, asCaller: false);
    await _media.acceptRemote(offer);
    final answer = await _media.createAnswer();

    _signal.send({
      'type': 'call.answer',
      'call_id': start.callId,
      'sdp': answer,
    });

    _ring?.cancel();
    wasAnswered = true;
    _moveTo(CallPhase.connecting);
  }

  Future<void> decline() => _end('declined', tell: true);

  Future<void> hangUp() => _end('hangup', tell: true);

  Future<void> _end(String reason, {required bool tell}) async {
    if (phase == CallPhase.ended) return;

    _ring?.cancel();
    endReason = reason;
    endedByMe = tell;
    if (tell && _start != null) {
      _signal.send({
        'type': 'call.end',
        'call_id': _start!.callId,
        'reason': reason,
      });
    }

    await _media.stop();
    _moveTo(CallPhase.ended);
  }

  void onLocalCandidate(Map<String, dynamic> candidate) {
    final start = _start;
    if (start == null || phase == CallPhase.ended) return;

    _signal.send({
      'type': 'call.ice',
      'call_id': start.callId,
      'candidate': candidate,
    });
  }

  void onConnectionChanged(bool connected) {
    if (phase == CallPhase.ended) return;

    if (connected) {
      connectedAt ??= DateTime.now();
      _moveTo(CallPhase.connected);
      return;
    }

    if (phase == CallPhase.connected) _moveTo(CallPhase.connecting);
  }

  void onConnectionFailed() {
    if (phase == CallPhase.ended) return;
    unawaited(_end('failed', tell: true));
  }

  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _media.setMuted(isMuted);

    final start = _start;
    if (start != null) {
      _signal.send({
        'type': 'call.update',
        'call_id': start.callId,
        'media': start.media,
        'muted': isMuted,
      });
    }
    onChanged?.call();
  }

  Future<void> toggleSpeaker() async {
    isSpeakerOn = !isSpeakerOn;
    await _media.setSpeaker(isSpeakerOn);
    onChanged?.call();
  }

  Future<void> onEvent(Map<String, dynamic> event) async {
    final start = _start;
    if (start == null) return;
    if (event['call_id'] != start.callId) return;

    switch (event['type']) {
      case 'call.answer':
        final sdp = event['sdp'];
        if (sdp is String) {
          _ring?.cancel();
          wasAnswered = true;
          await _media.acceptRemote(sdp);
          _moveTo(CallPhase.connecting);
        }
      case 'call.ice':
        final candidate = event['candidate'];
        if (candidate is Map) {
          await _media.addCandidate(Map<String, dynamic>.from(candidate));
        }
      case 'call.update':
        final media = event['media'];
        if (media is List) {
          peerMedia = media.map((kind) => kind as String).toList();
          onChanged?.call();
        }
      case 'call.end':
        await _end(event['reason'] as String? ?? 'hangup', tell: false);
      case 'call.state':
        if (event['state'] == 'timeout' || event['state'] == 'offline') {
          await _end(event['state'] as String, tell: false);
        }
    }
  }
}
