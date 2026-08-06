import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const shellScreens = {
  'feed_screen.dart',
  'chat_list_screen.dart',
  'profile_screen.dart',
  'notifications_screen.dart',
};

void main() {
  test('every screen outside the shell brings its own Scaffold', () {
    final offenders = <String>[];

    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_screen.dart')) continue;
      final name = entity.uri.pathSegments.last;
      if (shellScreens.contains(name)) continue;

      final source = entity.readAsStringSync();
      final hasScaffold =
          source.contains('Scaffold(') || source.contains('AppScaffold(');
      if (!hasScaffold) offenders.add(name);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These screens render outside AppShell, so InkWell and friends have '
          'no Material ancestor and will throw at runtime: $offenders',
    );
  });
}
