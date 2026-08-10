import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/components/avatar_face.dart';
import 'package:story_app/core/utils/avatar_seeds.dart';

void main() {
  test('there are ten faces, five of each', () {
    expect(faceStyles.length, faceCount);
    expect(faceCount, 10);
    expect(faceStyles.where((style) => style.isLongHair).length, 5);
    expect(faceStyles.where((style) => !style.isLongHair).length, 5);
  });

  test('no two men share a hairstyle', () {
    final men = faceStyles.where((style) => !style.isLongHair).map((s) => s.style);
    expect(men.toSet().length, 5);
  });

  test('the deepest skin tones get textured hair, not a flat cap', () {
    final textured = faceStyles.where(
      (style) => style.style == HairStyle.curls || style.style == HairStyle.afro,
    );
    expect(textured.length, 2);
  });

  test('every face has its own skin tone within its half', () {
    final women = faceStyles.where((style) => style.isLongHair).map((s) => s.skin);
    final men = faceStyles.where((style) => !style.isLongHair).map((s) => s.skin);

    expect(women.toSet().length, 5);
    expect(men.toSet().length, 5);
  });

  test('the picker offers each face exactly once', () {
    final seeds = faceSeeds();

    expect(seeds.length, faceCount);
    expect(seeds.map(faceIndexFor).toSet().length, faceCount);
  });

  test('the seed you already wear keeps its place', () {
    final mine = faceSeeds()[4];
    final seeds = faceSeeds(keep: mine);

    expect(seeds, contains(mine));
    expect(seeds[faceIndexFor(mine)], mine);
    expect(seeds.map(faceIndexFor).toSet().length, faceCount);
  });

  test('a seed always draws the same face', () {
    expect(faceIndexFor('aabbccddeeff0011'), faceIndexFor('aabbccddeeff0011'));
    expect(faceIndexFor(''), 0);
  });

  test('every generated seed is a sixteen character hex string', () {
    for (final seed in faceSeeds()) {
      expect(seed, matches(RegExp(r'^[0-9a-f]{16}$')));
    }
  });
}
