import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../core/security/call_ui.dart';
import '../../../core/webrtc/webrtc_media.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_providers.dart';
import '../data/call_repository.dart';
import '../data/call_session.dart';
import '../models/call_models.dart';

final callRepositoryProvider = Provider<CallRepository>(
  (ref) => CallRepository(ref.watch(apiClientProvider)),
);

final callHistoryProvider = FutureProvider<List<CallRecord>>((ref) async {
  final result = await ref.watch(callRepositoryProvider).history();
  return result.valueOrNull?.items ?? const [];
});

class _SocketSignal implements CallSignal {
  _SocketSignal(this._client);

  final RealtimeClient _client;

  @override
  void send(Map<String, dynamic> event) => _client.send(event);
}

class CallController extends StateNotifier<CallSession?> {
  CallController(this._ref) : super(null) {
    _live = _ref.read(realtimeProvider).events.listen(_onEvent);
    unawaited(CallUi.requestNotifications());
  }

  final Ref _ref;
  StreamSubscription<RealtimeEvent>? _live;

  CallSession _newSession() {
    final signal = _SocketSignal(_ref.read(realtimeProvider));
    late final CallSession session;
    final media = WebRtcMedia(
      onLocalCandidate: (candidate) => session.onLocalCandidate(candidate),
      onConnectionChanged: (connected) => session.onConnectionChanged(connected),
    );
    session = CallSession(media: media, signal: signal)
      ..onChanged = () {
        if (mounted) state = session;
      };
    return session;
  }

  Future<String?> place(String conversationId) async {
    if (state != null && !state!.isOver) return 'A call is already in progress.';

    if (!await CallUi.requestMicrophone()) {
      return 'STORY needs the microphone to place a call.';
    }

    final result = await _ref.read(callRepositoryProvider).start(conversationId);
    final start = result.valueOrNull;
    if (start == null) return result.failureOrNull?.message ?? 'Could not start the call.';

    final session = _newSession();
    state = session;
    try {
      await session.place(start);
    } catch (error) {
      state = null;
      await session.hangUp();
      return 'The call could not start: $error';
    }
    await CallUi.startOngoing(start.peer.displayName);
    return null;
  }

  Future<String?> accept() async {
    await CallUi.stopRinging();
    if (!await CallUi.requestMicrophone()) {
      return 'STORY needs the microphone to answer.';
    }
    try {
      await state?.accept();
    } catch (error) {
      await state?.hangUp();
      return 'The call could not connect: $error';
    }
    final peer = state?.peer;
    if (peer != null) await CallUi.startOngoing(peer.displayName);
    return null;
  }

  Future<void> decline() async {
    await CallUi.stopRinging();
    await state?.decline();
    await CallUi.stopOngoing();
    _clearWhenOver();
  }

  Future<void> hangUp() async {
    await CallUi.stopRinging();
    await state?.hangUp();
    await CallUi.stopOngoing();
    _clearWhenOver();
  }

  Future<void> toggleMute() async => state?.toggleMute();

  Future<void> toggleSpeaker() async => state?.toggleSpeaker();

  void _clearWhenOver() {
    if (state?.isOver ?? false) {
      unawaited(CallUi.stopRinging());
      unawaited(CallUi.stopOngoing());
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (mounted && (state?.isOver ?? false)) state = null;
      });
    }
  }

  Future<void> _onEvent(RealtimeEvent event) async {
    final type = event['type'];
    if (type is! String || !type.startsWith('call.')) return;

    if (type == 'call.offer') {
      await _onOffer(event);
      return;
    }

    final session = state;
    if (session != null) {
      await session.onEvent(event);
      if (session.isOver) {
        await CallUi.stopRinging();
        await CallUi.stopOngoing();
        _clearWhenOver();
      }
    }
  }

  Future<void> _onOffer(RealtimeEvent event) async {
    final callId = event['call_id'];
    final sdp = event['sdp'];
    if (callId is! String || sdp is! String) return;

    final busy = state != null && !state!.isOver;
    if (busy) {
      _ref.read(realtimeProvider).send({
        'type': 'call.end',
        'call_id': callId,
        'reason': 'busy',
      });
      return;
    }

    final caller = event['caller'];
    final start = CallStart.fromJson({
      'call_id': callId,
      'conversation_id': event['conversation_id'] ?? '',
      'media': event['media'] ?? const ['audio'],
      'peer': caller is Map
          ? Map<String, dynamic>.from(caller)
          : {'user_id': event['from'] ?? '', 'username': '', 'display_name': 'Someone'},
      'ice_servers': event['ice_servers'] ?? const [],
      'ring_timeout_seconds': event['ring_timeout_seconds'] ?? 45,
    });

    final session = _newSession();
    await session.receive(start, offer: sdp);
    state = session;
    await CallUi.ring(callId: callId, caller: start.peer.displayName);
    onIncoming?.call();
  }

  void Function()? onIncoming;

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }
}

final callControllerProvider =
    StateNotifierProvider<CallController, CallSession?>(
      CallController.new,
    );
