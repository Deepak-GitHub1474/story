import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/core/utils/avatar_seeds.dart';

void main() {
  test('a batch has the asked-for number of seeds', () {
    expect(newAvatarSeeds(12).length, 12);
  });

  test('every seed is sixteen hex characters', () {
    for (final seed in newAvatarSeeds(24)) {
      expect(seed, matches(RegExp(r'^[0-9a-f]{16}$')));
    }
  });

  test('a batch has no duplicates', () {
    final seeds = newAvatarSeeds(30);
    expect(seeds.toSet().length, seeds.length);
  });

  test('two batches differ', () {
    expect(newAvatarSeeds(8), isNot(newAvatarSeeds(8)));
  });

  test('the current seed is kept at the front when given', () {
    final seeds = newAvatarSeeds(6, keep: 'aabbccddeeff0011');
    expect(seeds.first, 'aabbccddeeff0011');
    expect(seeds.length, 6);
  });

  test('the kept seed is not repeated later in the batch', () {
    final seeds = newAvatarSeeds(20, keep: 'aabbccddeeff0011');
    expect(seeds.where((s) => s == 'aabbccddeeff0011').length, 1);
  });
}
