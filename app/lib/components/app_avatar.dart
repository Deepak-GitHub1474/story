import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar_face.dart';

String initialFor({required String? displayName, required String username}) {
  for (final candidate in [displayName ?? '', username]) {
    for (final rune in candidate.trim().runes) {
      final character = String.fromCharCode(rune);
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(character)) {
        return character.toUpperCase();
      }
    }
  }
  return '?';
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.seed,
    this.size = 56,
    this.displayName,
    this.username,
  });

  final String seed;
  final double size;
  final String? displayName;
  final String? username;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.border,
          width: AppSizes.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AvatarFace(seed: seed, size: size),
    );
  }
}
