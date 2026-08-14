import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _screen() =>
    File('lib/features/account/screens/forgot_password_screen.dart')
        .readAsStringSync();

void main() {
  test('the reset warning says the chats go', () {
    expect(
      _screen().contains('they are cleared from here'),
      isTrue,
      reason: 'a reset erases chat, so nobody should meet that as a surprise',
    );
  });

  test('the reset warning says the other person keeps theirs', () {
    expect(_screen().contains('keeps their own copy'), isTrue);
  });

  test('the reset warning still promises the vault is untouched', () {
    expect(_screen().contains('its own passcode'), isTrue);
  });

  test('the box you tick names the chats too', () {
    expect(_screen().contains('my chats will be cleared'), isTrue);
  });
}
