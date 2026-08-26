import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/calls/models/call_models.dart';

void main() {
  group('what the server hands back when a call starts', () {
    final json = {
      'call_id': 'cal_1',
      'conversation_id': 'cnv_1',
      'media': ['audio'],
      'peer': {
        'user_id': 'usr_2',
        'username': 'paper_lantern',
        'display_name': 'paper_lantern',
        'avatar_seed': 'abc',
      },
      'ice_servers': [
        {'urls': ['stun:stun.example.org:19302']},
        {
          'urls': ['turn:relay.example.org:3478', 'turns:relay.example.org:443'],
          'username': '1799999999:usr_1',
          'credential': 'c2lnbmF0dXJl',
        },
      ],
      'ring_timeout_seconds': 45,
    };

    test('every field survives the trip', () {
      final start = CallStart.fromJson(json);

      expect(start.callId, 'cal_1');
      expect(start.conversationId, 'cnv_1');
      expect(start.media, ['audio']);
      expect(start.peer.username, 'paper_lantern');
      expect(start.ringTimeoutSeconds, 45);
    });

    test('ice servers keep the shape WebRTC expects', () {
      final start = CallStart.fromJson(json);

      expect(start.iceServers.length, 2);
      expect(start.iceServers.last.urls.length, 2);
      expect(start.iceServers.last.username, '1799999999:usr_1');
    });

    test('an ice server becomes the map the plugin wants', () {
      final relay = CallStart.fromJson(json).iceServers.last;

      expect(relay.toMap(), {
        'urls': ['turn:relay.example.org:3478', 'turns:relay.example.org:443'],
        'username': '1799999999:usr_1',
        'credential': 'c2lnbmF0dXJl',
      });
    });

    test('a stun server carries no credentials', () {
      final stun = CallStart.fromJson(json).iceServers.first;

      expect(stun.toMap(), {
        'urls': ['stun:stun.example.org:19302'],
      });
    });

    test('media is a list so video needs no new model', () {
      final start = CallStart.fromJson({...json, 'media': ['audio', 'video']});

      expect(start.media, ['audio', 'video']);
      expect(start.hasVideo, isTrue);
    });

    test('an audio call knows it has no video', () {
      expect(CallStart.fromJson(json).hasVideo, isFalse);
    });
  });

  group('a row in the call history', () {
    final json = {
      'call_id': 'cal_1',
      'peer_id': 'usr_2',
      'conversation_id': 'cnv_1',
      'direction': 'out',
      'outcome': 'answered',
      'media': ['audio'],
      'relayed': true,
      'started_at': '2026-08-26T10:00:00Z',
      'duration_seconds': 95,
    };

    test('it reads every field', () {
      final record = CallRecord.fromJson(json);

      expect(record.callId, 'cal_1');
      expect(record.direction, CallDirection.outgoing);
      expect(record.outcome, CallOutcome.answered);
      expect(record.relayed, isTrue);
      expect(record.durationSeconds, 95);
      expect(record.startedAt.year, 2026);
    });

    test('an inbound call is read as inbound', () {
      final record = CallRecord.fromJson({...json, 'direction': 'in'});

      expect(record.direction, CallDirection.incoming);
    });

    test('a call nobody answered is a missed call', () {
      final record = CallRecord.fromJson({
        ...json,
        'outcome': 'missed',
        'duration_seconds': 0,
      });

      expect(record.outcome, CallOutcome.missed);
      expect(record.wasAnswered, isFalse);
    });

    test('an outcome the app does not know does not crash it', () {
      final record = CallRecord.fromJson({...json, 'outcome': 'evaporated'});

      expect(record.outcome, CallOutcome.failed);
    });

    test('duration reads as minutes and seconds', () {
      expect(CallRecord.fromJson(json).spoken, '1:35');
      expect(
        CallRecord.fromJson({...json, 'duration_seconds': 3661}).spoken,
        '61:01',
      );
      expect(
        CallRecord.fromJson({...json, 'duration_seconds': 0}).spoken,
        isNull,
      );
    });
  });

  group('a page of history', () {
    test('it carries the cursor forward', () {
      final page = CallHistoryPage.fromJson({
        'items': [],
        'next_cursor': '1799999999.000000|chi_1',
        'has_more': true,
      });

      expect(page.hasMore, isTrue);
      expect(page.nextCursor, '1799999999.000000|chi_1');
    });

    test('the last page has no cursor', () {
      final page = CallHistoryPage.fromJson({
        'items': [],
        'next_cursor': null,
        'has_more': false,
      });

      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });
}
