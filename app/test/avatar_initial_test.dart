import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/app_avatar.dart';

void main() {
  test('the display name wins', () {
    expect(initialFor(displayName: 'Deepak', username: 'dev_vinit'), 'D');
  });

  test('the username is used when there is no display name', () {
    expect(initialFor(displayName: null, username: 'dev_vinit'), 'D');
  });

  test('a blank display name falls through to the username', () {
    expect(initialFor(displayName: '   ', username: 'vinit'), 'V');
  });

  test('a leading symbol is skipped in favour of a letter', () {
    expect(initialFor(displayName: '_deepak', username: 'x'), 'D');
  });

  test('a digit is used when there is no letter', () {
    expect(initialFor(displayName: '9lives', username: 'x'), '9');
  });

  test('an emoji name still gives something', () {
    expect(initialFor(displayName: '🌤', username: 'sunny'), 'S');
  });

  test('nothing at all gives a question mark', () {
    expect(initialFor(displayName: null, username: ''), '?');
  });

  test('it is always uppercase', () {
    expect(initialFor(displayName: 'deepak', username: 'x'), 'D');
  });
}
