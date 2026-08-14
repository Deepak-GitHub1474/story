import 'package:flutter/material.dart';

import '../../../components/app_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/story_models.dart';

const likedByPreview = 3;

class LikedByRow extends StatelessWidget {
  const LikedByRow({
    super.key,
    required this.people,
    required this.likes,
    this.onTap,
  });

  final List<StoryAuthor> people;
  final int likes;
  final VoidCallback? onTap;

  static const _face = 18.0;
  static const _step = 12.0;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty || likes == 0) return const SizedBox.shrink();

    final colors = context.colors;
    final shown = people.take(likedByPreview).toList();
    final rest = likes - 1;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: _face + _step * (shown.length - 1),
            height: _face + 2,
            child: Stack(
              children: [
                for (var index = shown.length - 1; index >= 0; index--)
                  Positioned(
                    left: index * _step,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.bg, width: 1.5),
                      ),
                      child: AppAvatar(
                        seed: shown[index].avatarSeed,
                        size: _face,
                        displayName: shown[index].displayName,
                        username: shown[index].username,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Liked by '),
                  TextSpan(
                    text: shown.first.handle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (rest > 0)
                    TextSpan(text: rest == 1 ? ' and 1 other' : ' and others'),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: AppTypeScale.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
