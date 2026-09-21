import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/calls/data/call_session.dart';
import 'package:story_app/features/calls/models/call_models.dart';

import 'call_session_test_doubles.dart';

Map<String, dynamic> anOffer({Map<String, dynamic>? caller}) => {
  'type': 'call.offer',
  'call_id': 'cal_1',
  'from': 'usr_2',
  'conversation_id': 'cnv_1',
  'media': ['audio'],
  'sdp': 'sdp-offer',
  'ring_timeout_seconds': 45,
  'ice_servers': [
    {'urls': ['stun:stun.example.org:19302']},
    {
      'urls': ['turn:relay.example.org:3478'],
      'username': '1799999999:usr_2',
      'credential': 'sig',
    },
  ],
  'caller': caller ??
      {
        'user_id': 'usr_2',
        'username': 'paper_lantern',
        'display_name': 'paper_lantern',
        'avatar_seed': 'seed-abc',
      },
};

void main() {
  test('an offer carries everything the callee needs to answer', () {
    final event = anOffer();

    final start = CallStart.fromJson({
      'call_id': event['call_id'],
      'conversation_id': event['conversation_id'],
      'media': event['media'],
      'peer': event['caller'],
      'ice_servers': event['ice_servers'],
      'ring_timeout_seconds': event['ring_timeout_seconds'],
    });

    expect(start.callId, 'cal_1');
    expect(start.peer.displayName, 'paper_lantern');
    expect(start.peer.avatarSeed, 'seed-abc');
    expect(start.iceServers.length, 2);
    expect(start.iceServers.last.username, '1799999999:usr_2');
  });

  test('a received offer puts the session in ringing, not idle', () async {
    final media = FakeMedia();
    final signal = FakeSignal();
    final session = CallSession(media: media, signal: signal);

    final event = anOffer();
    await session.receive(
      CallStart.fromJson({
        'call_id': event['call_id'],
        'conversation_id': event['conversation_id'],
        'media': event['media'],
        'peer': event['caller'],
        'ice_servers': event['ice_servers'],
        'ring_timeout_seconds': event['ring_timeout_seconds'],
      }),
      offer: event['sdp'] as String,
    );

    expect(session.phase, CallPhase.ringing);
    expect(session.isIncoming, isTrue);
    expect(session.peer!.avatarSeed, 'seed-abc');
  });

  test('an outgoing call is not marked incoming', () async {
    final session = CallSession(media: FakeMedia(), signal: FakeSignal());

    await session.place(
      CallStart.fromJson({
        'call_id': 'cal_1',
        'conversation_id': 'cnv_1',
        'media': ['audio'],
        'peer': {'user_id': 'usr_2', 'username': 'bo', 'display_name': 'bo'},
        'ice_servers': [],
        'ring_timeout_seconds': 45,
      }),
    );

    expect(session.isIncoming, isFalse);
  });

  test('an unanswered call ends itself so it can be recorded as missed', () async {
    final media = FakeMedia();
    final signal = FakeSignal();
    final session = CallSession(media: media, signal: signal);

    await session.place(
      CallStart.fromJson({
        'call_id': 'cal_1',
        'conversation_id': 'cnv_1',
        'media': ['audio'],
        'peer': {'user_id': 'usr_2', 'username': 'bo', 'display_name': 'bo'},
        'ice_servers': [],
        'ring_timeout_seconds': 1,
      }),
    );
    signal.sent.clear();

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(session.phase, CallPhase.ended);
    expect(session.endReason, 'timeout');
    expect(signal.sent.single['type'], 'call.end');
    expect(signal.sent.single['reason'], 'timeout');
  });

  test('answering before the timeout stops it firing', () async {
    final session = CallSession(media: FakeMedia(), signal: FakeSignal());

    await session.receive(
      CallStart.fromJson({
        'call_id': 'cal_1',
        'conversation_id': 'cnv_1',
        'media': ['audio'],
        'peer': {'user_id': 'usr_2', 'username': 'bo', 'display_name': 'bo'},
        'ice_servers': [],
        'ring_timeout_seconds': 1,
      }),
      offer: 'sdp-offer',
    );
    await session.accept();

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(session.phase, CallPhase.connecting);
    expect(session.endReason, isNull);
  });
}
