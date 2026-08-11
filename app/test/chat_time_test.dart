import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/utils/chat_time.dart';

String isoOf(DateTime local) => local.toUtc().toIso8601String();

void main() {
  group('the clock', () {
    test('midnight reads as twelve, not zero', () {
      expect(clockOf(DateTime(2026, 8, 11, 0, 5)), '12:05 AM');
    });

    test('noon reads as twelve PM', () {
      expect(clockOf(DateTime(2026, 8, 11, 12, 0)), '12:00 PM');
    });

    test('one minute before noon is still AM', () {
      expect(clockOf(DateTime(2026, 8, 11, 11, 59)), '11:59 AM');
    });

    test('the evening reads on a twelve hour clock', () {
      expect(clockOf(DateTime(2026, 8, 11, 17, 5)), '5:05 PM');
    });

    test('minutes always carry two digits', () {
      expect(clockOf(DateTime(2026, 8, 11, 9, 4)), '9:04 AM');
    });

    test('a stamp from the wire is shown in local time', () {
      final local = DateTime(2026, 8, 11, 6, 49);
      expect(messageClock(isoOf(local)), '6:49 AM');
    });

    test('nothing in, nothing out', () {
      expect(messageClock(null), '');
      expect(messageClock('not a date'), '');
    });
  });

  group('the day separator', () {
    final now = DateTime(2026, 8, 11, 10, 0);

    test('today is named, not dated', () {
      expect(daySeparator(DateTime(2026, 8, 11, 1, 0), now: now), 'TODAY');
    });

    test('a message at one minute past midnight is still today', () {
      expect(daySeparator(DateTime(2026, 8, 11, 0, 1), now: now), 'TODAY');
    });

    test('late last night is yesterday, not today', () {
      expect(daySeparator(DateTime(2026, 8, 10, 23, 59), now: now), 'YESTERDAY');
    });

    test('earlier this week carries its weekday', () {
      expect(daySeparator(DateTime(2026, 8, 8, 15, 46), now: now), 'SAT 08 AUG');
    });

    test('six days back is still inside the week', () {
      expect(daySeparator(DateTime(2026, 8, 5, 9, 0), now: now), 'WED 05 AUG');
    });

    test('seven days back drops the weekday', () {
      expect(daySeparator(DateTime(2026, 8, 4, 9, 0), now: now), '04 AUG');
    });

    test('this year needs no year', () {
      expect(daySeparator(DateTime(2026, 2, 2, 12, 20), now: now), '02 FEB');
    });

    test('an older year is spelled out in full', () {
      expect(daySeparator(DateTime(2025, 8, 2, 12, 20), now: now), '02 AUG 2025');
    });

    test('the first of January is not mistaken for this year', () {
      expect(daySeparator(DateTime(2025, 12, 31, 23, 0), now: now), '31 DEC 2025');
    });
  });

  group('grouping', () {
    test('the first message always opens a day', () {
      expect(startsNewDay(isoOf(DateTime(2026, 8, 11, 9, 0)), null), isTrue);
    });

    test('two messages on the same day do not repeat the header', () {
      final first = isoOf(DateTime(2026, 8, 11, 9, 0));
      final second = isoOf(DateTime(2026, 8, 11, 23, 30));
      expect(startsNewDay(second, first), isFalse);
    });

    test('crossing midnight opens a new day', () {
      final before = isoOf(DateTime(2026, 8, 10, 23, 59));
      final after = isoOf(DateTime(2026, 8, 11, 0, 1));
      expect(startsNewDay(after, before), isTrue);
    });

    test('the day is decided in local time, not UTC', () {
      final lateEvening = DateTime(2026, 8, 11, 23, 30);
      final local = localOf(isoOf(lateEvening))!;
      expect(isSameDay(local, lateEvening), isTrue);
    });
  });
}
