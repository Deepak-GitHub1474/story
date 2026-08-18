import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/identity/handle.dart';

void main() {
  test('a fresh account shows one name, not the same name twice', () {
    expect(
      handleFor(displayName: 'riverbend', username: 'riverbend'),
      isNull,
      reason: 'display_name defaults to the username, so both would read alike',
    );
  });

  test('case alone is not a difference worth showing', () {
    expect(handleFor(displayName: 'Riverbend', username: 'riverbend'), isNull);
  });

  test('surrounding space is not a difference either', () {
    expect(handleFor(displayName: ' riverbend ', username: 'riverbend'), isNull);
  });

  test('a chosen name keeps the handle, because it identifies them', () {
    expect(
      handleFor(displayName: 'River Bend', username: 'riverbend'),
      '@riverbend',
      reason: 'display names are not unique, so the handle still earns its place',
    );
  });

  test('a missing username shows nothing rather than a bare @', () {
    expect(handleFor(displayName: 'River', username: ''), isNull);
    expect(handleFor(displayName: 'River', username: '   '), isNull);
  });

  test('the same rule answers whether a display name is worth showing', () {
    expect(namesDiffer(displayName: 'riverbend', username: 'riverbend'), isFalse);
    expect(namesDiffer(displayName: 'River Bend', username: 'riverbend'), isTrue);
    expect(
      namesDiffer(displayName: 'River', username: ''),
      isFalse,
      reason: 'with no handle there is only one name, so nothing is redundant',
    );
  });
}
