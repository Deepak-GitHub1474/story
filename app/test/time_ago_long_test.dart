import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/utils/time_ago.dart';

String ago(Duration span) =>
    DateTime.now().toUtc().subtract(span).toIso8601String();

void main() {
  group('a story stamp reads in words', () {
    test('a fresh story is just now', () {
      expect(timeAgoLong(ago(const Duration(seconds: 20))), 'just now');
    });

    test('one minute stays singular', () {
      expect(timeAgoLong(ago(const Duration(minutes: 1))), '1 min ago');
    });

    test('many minutes turn plural', () {
      expect(timeAgoLong(ago(const Duration(minutes: 13))), '13 mins ago');
    });

    test('an hour is spelled out', () {
      expect(timeAgoLong(ago(const Duration(hours: 2))), '2 hours ago');
    });

    test('fifty nine minutes has not become an hour', () {
      expect(timeAgoLong(ago(const Duration(minutes: 59))), '59 mins ago');
    });

    test('a day is singular', () {
      expect(timeAgoLong(ago(const Duration(days: 1))), '1 day ago');
    });

    test('a week is still counted in days', () {
      expect(timeAgoLong(ago(const Duration(days: 7))), '7 days ago');
    });

    test('past a week it falls back to the date', () {
      final then = DateTime(2024, 8, 7, 10, 30);
      expect(timeAgoLong(then.toUtc().toIso8601String()), '7 August 2024');
    });

    test('eight days is already a date, not a count', () {
      final stamp = timeAgoLong(ago(const Duration(days: 8)));
      expect(stamp, isNot(contains('ago')));
    });

    test('the date is written in the reader own time', () {
      final then = DateTime(2025, 1, 3, 23, 45);
      expect(timeAgoLong(then.toUtc().toIso8601String()), '3 January 2025');
    });

    test('an empty stamp shows nothing', () {
      expect(timeAgoLong(null), '');
      expect(timeAgoLong(''), '');
      expect(timeAgoLong('not a date'), '');
    });

    test('the compact form is untouched for chats and alerts', () {
      expect(timeAgo(ago(const Duration(minutes: 13))), '13m');
      expect(timeAgo(ago(const Duration(hours: 2))), '2h');
    });
  });
}
