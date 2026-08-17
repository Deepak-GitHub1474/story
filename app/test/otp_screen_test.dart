import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/recovery_glyphs.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/core/utils/otp_wait.dart';
import 'package:story_app/features/account/screens/forgot_password_screen.dart';

import 'small_screen_test.dart' show show;

Failure<Object?> refused(String code, Map<String, dynamic> extra) => Failure(
  code: code,
  message: 'That code is not right.',
  statusCode: code == 'OTP_INVALID' ? 400 : 429,
  details: {'code': code, ...extra},
);

void main() {
  group('the clock on the code', () {
    test('ten minutes reads as ten minutes', () {
      expect(clockLabel(const Duration(minutes: 10)), '10:00');
    });

    test('the seconds keep two digits', () {
      expect(clockLabel(const Duration(minutes: 9, seconds: 8)), '9:08');
    });

    test('a code that ran out reads as nothing left', () {
      expect(clockLabel(Duration.zero), '0:00');
      expect(clockLabel(const Duration(seconds: -4)), '0:00');
    });
  });

  group('asking for another code', () {
    test('the wait is counted down in seconds', () {
      expect(resendLabel(const Duration(seconds: 30)), 'Send again in 30s');
    });

    test('once the wait is over it offers to send', () {
      expect(resendLabel(Duration.zero), 'Send it again');
    });
  });

  group('being shut out', () {
    test('a lock is recognised by how long it has to run', () {
      expect(
        lockedWait(refused('OTP_LOCKED', {'retry_after_seconds': 900})),
        const Duration(minutes: 15),
      );
    });

    test('a wrong code is not a lock', () {
      expect(
        lockedWait(refused('OTP_INVALID', {'attempts_remaining': 2})),
        isNull,
      );
    });

    test('a lock with no time on it falls back to plain words', () {
      expect(lockedWait(refused('OTP_LOCKED', {})), isNull);
      expect(
        otpTrouble(refused('OTP_LOCKED', {})),
        'Too many tries. Come back a little later.',
      );
    });

    test('the shut-out line counts itself down', () {
      expect(
        lockedLabel(const Duration(minutes: 13, seconds: 58)),
        'Too many tries. Try again in 13:58',
      );
    });
  });

  group('the expiry line', () {
    test('it stays quiet while there is plenty of time', () {
      expect(
        expiryLabel(const Duration(minutes: 9, seconds: 37)),
        isNull,
        reason: 'a clock ticking for ten minutes is noise, not information',
      );
    });

    test('it speaks up in the last two minutes', () {
      expect(
        expiryLabel(const Duration(minutes: 1, seconds: 30)),
        'Expires in 1:30',
      );
    });

    test('it says so once the code is dead', () {
      expect(expiryLabel(Duration.zero), 'That code has run out');
    });
  });

  group('what a refused code says', () {
    test('it counts the tries that are left', () {
      expect(
        otpTrouble(refused('OTP_INVALID', {'attempts_remaining': 3})),
        'That code is not right. 3 tries left.',
      );
    });

    test('the last try is spoken of in the singular', () {
      expect(
        otpTrouble(refused('OTP_INVALID', {'attempts_remaining': 1})),
        'That code is not right. One try left.',
      );
    });

    test('a locked account is told how long to wait', () {
      expect(
        otpTrouble(refused('OTP_LOCKED', {'retry_after_seconds': 900})),
        'Too many tries. Come back in about 15 minutes.',
      );
    });

    test('being rate limited reads the same way', () {
      expect(
        otpTrouble(refused('RATE_LIMITED', {'retry_after_seconds': 45})),
        'Too many tries. Come back in 45 seconds.',
      );
    });

    test('with nothing to go on it falls back to what the server said', () {
      expect(otpTrouble(refused('OTP_INVALID', {})), 'That code is not right.');
    });
  });

  group('the drawn touches', () {
    testWidgets('asking for a code is kept plain', (tester) async {
      await show(
        tester,
        const ForgotPasswordScreen(),
        size: const Size(390, 800),
        textScale: 1,
      );

      expect(find.byType(EnvelopeGlyph), findsNothing);
      expect(find.byType(KeyholeGlyph), findsNothing);
    });

    test('no recovery screen reaches for a drawn glyph any more', () {
      const screens = [
        'lib/features/account/screens/forgot_password_screen.dart',
        'lib/features/account/screens/email_screen.dart',
      ];

      for (final path in screens) {
        final source = File(path).readAsStringSync();
        for (final glyph in ['EnvelopeGlyph', 'KeyholeGlyph']) {
          expect(
            source.contains(glyph),
            isFalse,
            reason: '$path still draws $glyph, and these screens stay plain',
          );
        }
      }
    });
  });

  group('nothing hides below the fold', () {
    for (final phone in {
      'a tall phone': const Size(393, 852),
      'an average phone': const Size(390, 800),
    }.entries) {
      testWidgets('asking for a code fits on ${phone.key}', (tester) async {
        await show(
          tester,
          const ForgotPasswordScreen(),
          size: phone.value,
          textScale: 1,
        );

        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;

        expect(position.maxScrollExtent, 0);
      });
    }
  });
}
