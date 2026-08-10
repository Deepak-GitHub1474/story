import 'dart:math';

import '../../components/avatar_face.dart';

const _hex = '0123456789abcdef';

String _seed(Random random) =>
    List.generate(16, (_) => _hex[random.nextInt(16)]).join();

List<String> newAvatarSeeds(int count, {String? keep}) {
  final random = Random.secure();
  final seeds = <String>{if (keep != null && keep.isNotEmpty) keep};

  while (seeds.length < count) {
    seeds.add(_seed(random));
  }
  return seeds.toList();
}

List<String> faceSeeds({String? keep}) {
  final random = Random.secure();
  final chosen = List<String?>.filled(faceCount, null);

  if (keep != null && keep.isNotEmpty) {
    chosen[faceIndexFor(keep)] = keep;
  }

  for (var index = 0; index < faceCount; index += 1) {
    while (chosen[index] == null) {
      final candidate = _seed(random);
      if (faceIndexFor(candidate) == index) chosen[index] = candidate;
    }
  }

  return chosen.cast<String>();
}
