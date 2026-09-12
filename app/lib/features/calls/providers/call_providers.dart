import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../core/push/call_push.dart';
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
    _pushes = FirebaseMessaging.onMessage.listen(_onPush);
    unawaited(CallUi.requestNotifications());
    unawaited(_adoptAnythingWaiting());
    CallUi.onIntent(_onNotificationIntent);
  }

  final Ref _ref;
  StreamSubscription<RealtimeEvent>? _live;

  @override
  bool updateShouldNotify(CallSession? old, CallSession? current) => true;

  StreamSubscription<RemoteMessage>? _pushes;

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
      await CallUi.volumeForCall();
      await CallUi.startRingback();
      await CallUi.startOngoing(start.peer.displayName, start.callId);
    } catch (error) {
      state = null;
      await session.hangUp();
      return 'The call could not start: $error';
    }
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
    final id = state?.callId;
    if (peer != null && id != null) {
      await CallUi.startOngoing(peer.displayName, id);
    }
    await CallUi.volumeForCall();
    await CallUi.stopRingback();
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

  Future<void> replyAndDecline(String text) async {
    final conversationId = state?.start?.conversationId;

    await decline();

    if (conversationId == null || conversationId.isEmpty) return;
    unawaited(_sendReply(conversationId, text));
  }

  Future<void> _sendReply(String conversationId, String text) async {
    final alive = _ref.listen(
      conversationProvider(conversationId),
      (_, _) {},
      fireImmediately: true,
    );

    try {
      final chat = _ref.read(conversationProvider(conversationId).notifier);

      for (var waited = 0; waited < 60; waited++) {
        if (alive.read().hasKey) break;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      if (!alive.read().hasKey) return;
      await chat.send(text);
    } finally {
      alive.close();
      _ref.invalidate(conversationsProvider(null));
      _ref.invalidate(chatUnreadProvider);
    }
  }

  Future<void> silenceRing() async {
    await CallUi.hideRingNotification();
  }

  Future<void> toggleMute() async => state?.toggleMute();

  Future<void> toggleSpeaker() async => state?.toggleSpeaker();

  void _clearWhenOver() {
    if (!(state?.isOver ?? false)) return;

    unawaited(CallUi.stopRinging());
    unawaited(CallUi.stopRingback());
    unawaited(CallUi.stopOngoing());
    _ref.invalidate(callHistoryProvider);
  }

  void dismiss() {
    if (state?.isOver ?? false) state = null;
  }

  Future<void> _onPush(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    if (!isCallPush(data)) return;

    if (data['kind'] == callCancelledKind) {
      await CallUi.stopRinging();
      return;
    }

    final callId = data['call_id'];
    if (callId is String) await adopt(callId);
  }

  Future<void> _onNotificationIntent(String callId, String? action) async {
    await adopt(callId);

    if (action == 'answer') {
      await accept();
    } else if (action == 'decline') {
      await decline();
    } else if (action == 'hangup') {
      await hangUp();
    } else {
      onIncoming?.call();
    }
  }

  Future<void> _adoptAnythingWaiting() async {
    final waiting = await CallUi.pendingCallId();
    if (waiting != null) {
      await adopt(waiting);
      return;
    }
    await checkRinging();
  }

  Future<void> checkRinging() async {
    if (state != null && !state!.isOver) return;

    final result = await _ref.read(callRepositoryProvider).ringing();
    final invite = result.valueOrNull;
    if (invite == null) return;

    final session = _newSession();
    await session.receive(invite.start, offer: invite.sdp);
    state = session;
    await CallUi.ring(
      callId: invite.start.callId,
      caller: invite.start.peer.displayName,
    );
    onIncoming?.call();
  }

  Future<void> adopt(String callId) async {
    if (state != null && !state!.isOver) {
      if (state!.callId == callId) return;
      return;
    }

    final result = await _ref.read(callRepositoryProvider).pending(callId);
    final invite = result.valueOrNull;
    if (invite == null) {
      await CallUi.stopRinging();
      return;
    }

    final session = _newSession();
    await session.receive(invite.start, offer: invite.sdp);
    state = session;
    await CallUi.ring(
      callId: invite.start.callId,
      caller: invite.start.peer.displayName,
    );
    onIncoming?.call();
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

      if (session.phase != CallPhase.ringing &&
          session.phase != CallPhase.dialling) {
        await CallUi.stopRingback();
      }

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
    await CallUi.volumeForRinging();
    await CallUi.ring(callId: callId, caller: start.peer.displayName);
    onIncoming?.call();
  }

  void Function()? onIncoming;

  @override
  void dispose() {
    _live?.cancel();
    _pushes?.cancel();
    super.dispose();
  }
}

final callControllerProvider =
    StateNotifierProvider<CallController, CallSession?>(
      CallController.new,
    );
