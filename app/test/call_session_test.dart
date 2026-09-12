import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/calls/data/call_session.dart';
import 'package:story_app/features/calls/models/call_models.dart';

import 'call_session_test_doubles.dart';

CallStart aStart() => CallStart.fromJson({
  'call_id': 'cal_1',
  'conversation_id': 'cnv_1',
  'media': ['audio'],
  'peer': {'user_id': 'usr_2', 'username': 'bo', 'display_name': 'bo'},
  'ice_servers': [
    {'urls': ['stun:stun.example.org:19302']},
  ],
  'ring_timeout_seconds': 45,
});

void main() {
  _guards();
  late FakeMedia media;
  late FakeSignal signal;
  late CallSession session;

  setUp(() {
    media = FakeMedia();
    signal = FakeSignal();
    session = CallSession(media: media, signal: signal);
  });

  test('a fresh session is idle', () {
    expect(session.phase, CallPhase.idle);
  });

  test('placing a call offers and moves to ringing', () async {
    await session.place(aStart());

    expect(media.did, contains('start:caller'));
    expect(media.did, contains('offer'));
    expect(signal.sent.single['type'], 'call.offer');
    expect(signal.sent.single['sdp'], 'sdp-offer');
    expect(signal.sent.single['media'], ['audio']);
    expect(session.phase, CallPhase.ringing);
  });

  test('the answer moves the caller to connecting', () async {
    await session.place(aStart());

    await session.onEvent({
      'type': 'call.answer',
      'call_id': 'cal_1',
      'sdp': 'sdp-answer',
    });

    expect(media.remoteDescription, 'sdp-answer');
    expect(session.phase, CallPhase.connecting);
  });

  test('answering a call sends an answer back', () async {
    await session.receive(aStart(), offer: 'sdp-offer');
    expect(session.phase, CallPhase.ringing);

    await session.accept();

    expect(media.did, contains('start:callee'));
    expect(media.remoteDescription, 'sdp-offer');
    expect(signal.sent.single['type'], 'call.answer');
    expect(signal.sent.single['sdp'], 'sdp-answer');
    expect(session.phase, CallPhase.connecting);
  });

  test('declining tells the other side and ends', () async {
    await session.receive(aStart(), offer: 'sdp-offer');

    await session.decline();

    expect(signal.sent.single['type'], 'call.end');
    expect(signal.sent.single['reason'], 'declined');
    expect(session.phase, CallPhase.ended);
    expect(media.did, contains('stop'));
  });

  test('hanging up tells the other side and ends', () async {
    await session.place(aStart());
    signal.sent.clear();

    await session.hangUp();

    expect(signal.sent.single['type'], 'call.end');
    expect(signal.sent.single['reason'], 'hangup');
    expect(session.phase, CallPhase.ended);
  });

  test('the other side hanging up ends the call without echoing back', () async {
    await session.place(aStart());
    signal.sent.clear();

    await session.onEvent({
      'type': 'call.end',
      'call_id': 'cal_1',
      'reason': 'hangup',
    });

    expect(session.phase, CallPhase.ended);
    expect(signal.sent, isEmpty);
    expect(media.did, contains('stop'));
  });

  test('candidates are forwarded both ways', () async {
    await session.place(aStart());
    signal.sent.clear();

    session.onLocalCandidate({'candidate': 'a'});
    await session.onEvent({
      'type': 'call.ice',
      'call_id': 'cal_1',
      'candidate': {'candidate': 'b'},
    });

    expect(signal.sent.single['type'], 'call.ice');
    expect(signal.sent.single['candidate'], {'candidate': 'a'});
    expect(media.candidates.single, {'candidate': 'b'});
  });

  test('an event for a different call is ignored', () async {
    await session.place(aStart());

    await session.onEvent({
      'type': 'call.end',
      'call_id': 'cal_other',
      'reason': 'hangup',
    });

    expect(session.phase, CallPhase.ringing);
  });

  test('connecting becomes connected when the media says so', () async {
    await session.place(aStart());
    await session.onEvent({
      'type': 'call.answer',
      'call_id': 'cal_1',
      'sdp': 'sdp-answer',
    });

    session.onConnectionChanged(true);

    expect(session.phase, CallPhase.connected);
    expect(session.connectedAt, isNotNull);
  });

  test('mute is remembered and reaches the media', () async {
    await session.place(aStart());

    await session.toggleMute();

    expect(session.isMuted, isTrue);
    expect(media.muted, isTrue);
  });

  test('mute is announced so the other side can show it', () async {
    await session.place(aStart());
    signal.sent.clear();

    await session.toggleMute();

    expect(signal.sent.single['type'], 'call.update');
    expect(signal.sent.single['muted'], isTrue);
    expect(signal.sent.single['media'], ['audio']);
  });

  test('the speaker toggles without touching the other side', () async {
    await session.place(aStart());
    signal.sent.clear();

    await session.toggleSpeaker();

    expect(media.speaker, isTrue);
    expect(signal.sent, isEmpty);
  });

  test('a ring nobody answers ends as a timeout', () async {
    await session.place(aStart());

    await session.onEvent({
      'type': 'call.state',
      'call_id': 'cal_1',
      'state': 'timeout',
    });

    expect(session.phase, CallPhase.ended);
    expect(session.endReason, 'timeout');
  });

  test('hanging up twice sends one goodbye', () async {
    await session.place(aStart());
    signal.sent.clear();

    await session.hangUp();
    await session.hangUp();

    expect(signal.sent.length, 1);
  });

  test('an update carrying video is a request the audio call ignores', () async {
    await session.place(aStart());

    await session.onEvent({
      'type': 'call.update',
      'call_id': 'cal_1',
      'media': ['audio', 'video'],
    });

    expect(session.peerMedia, ['audio', 'video']);
    expect(session.phase, CallPhase.ringing);
  });
}

void _guards() {
  test('answering twice sends one answer and starts media once', () async {
    final media = FakeMedia();
    final signal = FakeSignal();
    final session = CallSession(media: media, signal: signal);
    await session.receive(aStart(), offer: 'sdp-offer');

    await session.accept();
    await session.accept();

    expect(
      signal.sent.where((e) => e['type'] == 'call.answer').length,
      1,
    );
    expect(media.did.where((d) => d == 'start:callee').length, 1);
  });

  test('a failed peer connection ends the call instead of hanging', () async {
    final media = FakeMedia();
    final signal = FakeSignal();
    final session = CallSession(media: media, signal: signal);
    await session.place(aStart());
    signal.sent.clear();

    session.onConnectionFailed();
    await Future<void>.delayed(Duration.zero);

    expect(session.phase, CallPhase.ended);
    expect(session.endReason, 'failed');
    expect(signal.sent.single['reason'], 'failed');
  });

  test('a dropped connection on a live call does not end it', () async {
    final session = CallSession(media: FakeMedia(), signal: FakeSignal());
    await session.place(aStart());
    session.onConnectionChanged(true);

    session.onConnectionChanged(false);

    expect(session.phase, CallPhase.connecting);
    expect(session.isOver, isFalse);
  });
}
