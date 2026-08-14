import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/recovery_glyphs.dart';
import 'package:story_app/core/result.dart';
import 'package:story_app/core/utils/otp_wait.dart';
import 'package:story_app/features/account/screens/forgot_password_screen.dart';
import 'package:story_app/theme/app_theme.dart';

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
    testWidgets('the first step shows an envelope on its way', (tester) async {
      await show(
        tester,
        const ForgotPasswordScreen(),
        size: const Size(390, 800),
        textScale: 1,
      );

      expect(find.byType(EnvelopeGlyph), findsOneWidget);
    });

    testWidgets('the glyphs are drawn, not fetched', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: midnightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                EnvelopeGlyph(size: 64, color: Color(0xFFFFFFFF)),
                KeyholeGlyph(size: 64, color: Color(0xFFFFFFFF)),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(Image), findsNothing);
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
