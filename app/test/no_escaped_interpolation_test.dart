import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no source file escapes a Dart interpolation by accident', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (lines[index].contains(r'\$')) {
          offenders.add('${entity.path}:${index + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          r'These lines contain \$, which Dart reads as a literal dollar sign '
          'rather than an interpolation, so the string ships with the braces '
          'still in it: $offenders',
    );
  });
}
