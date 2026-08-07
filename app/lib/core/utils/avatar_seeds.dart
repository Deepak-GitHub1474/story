import 'dart:math';

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
